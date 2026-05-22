class CsvImporter
  Result = Struct.new(:imported_count, :error_count, :flagged_count, :errors, :imported_ids, keyword_init: true)

  def initialize(user:, csv_content: nil, file_path: nil, import_id: nil)
    @user = user
    @csv_content = csv_content
    @file_path = file_path
    @import_id = import_id
    @imported = 0
    @errors_list = []
    @flagged = 0
    # Start at 1 so that the first data row is reported as line 2 — matches
    # how text editors and spreadsheet apps number lines (header is line 1).
    @row_number = 1
    @imported_ids = []
  end

  def import
    source = @file_path || StringIO.new(@csv_content)

    SmarterCSV.process(source, chunk_size: 1000, strings_as_keys: true) do |chunk|
      process_chunk(chunk)
    end

    Result.new(
      imported_count: @imported,
      error_count: @errors_list.size,
      flagged_count: @flagged,
      errors: @errors_list,
      imported_ids: @imported_ids
    )
  end

  private

  def process_chunk(rows)
    valid_records = []

    rows.each do |row|
      @row_number += 1

      parsed = parse_row(row)
      next unless parsed

      valid_records << parsed
    end

    return if valid_records.empty?

    inserted = Transaction.insert_all(valid_records, returning: [:id])
    @imported += inserted.count
    @imported_ids.concat(inserted.rows.flatten)

    broadcast_progress if @import_id

    inserted.each do |record|
      tx = Transaction.find(record['id'])
      RulesEngine.apply(tx)
      AnomalyDetector.check(tx)
      @flagged += 1 if tx.reload.status == 'flagged'
    end
  end

  def parse_row(row)
    date = parse_date(row['date'])
    unless date
      @errors_list << "Row #{@row_number}: invalid date '#{row['date']}'"
      return nil
    end

    amount = parse_amount(row['amount'])
    unless amount
      @errors_list << "Row #{@row_number}: invalid amount '#{row['amount']}'"
      return nil
    end

    description = row['description'].to_s.strip.presence
    category = row['category'].to_s.strip.presence

    {
      user_id: @user.id,
      date: date,
      description: description,
      description_normalized: Transaction.normalize_description(description),
      amount: amount,
      category: category,
      status: 'pending',
      source: 'csv',
      anomaly_flags: [],
      metadata: {},
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value.to_s)
  rescue Date::Error, ArgumentError
    nil
  end

  def parse_amount(value)
    return nil if value.blank?
    amount = BigDecimal(value.to_s.gsub(/[,$]/, ''))
    amount.finite? ? amount : nil
  rescue ArgumentError
    nil
  end

  def broadcast_progress
    ActionCable.server.broadcast(
      "import_status_#{@import_id}",
      { processed: @imported + @errors_list.size, imported: @imported, errors: @errors_list.size }
    )
  end
end
