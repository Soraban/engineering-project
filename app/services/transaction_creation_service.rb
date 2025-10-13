class TransactionCreationService
  attr_reader :results

  def initialize
    @results = {
      success: 0,
      errors: [],
      imported_ids: []
    }
    # Cache categorization rules for performance (with categories to avoid N+1)
    @categorization_rules = CategorizationRule.active.includes(:category).order(priority: :desc).to_a
  end

  # Create a single transaction (for manual entry)
  def create_single(attributes)
    # Handle category string input by converting to category_id
    if attributes[:category].present? && attributes[:category_id].nil?
      category = Category.find_or_create_by!(name: attributes[:category])
      attributes = attributes.except(:category).merge(category_id: category.id)
    end
    
    transaction = Transaction.new(attributes)

    if transaction.save
      results[:success] += 1
      results[:imported_ids] << transaction.id

      # Apply categorization rules if uncategorized (using cached rules)
      if transaction.category_id.blank?
        category = find_matching_category(transaction)
        transaction.update_column(:category_id, category.id) if category
      end

      # Enqueue anomaly detection
      AnomalyDetectionJob.perform_later(transaction.id)

      transaction
    else
      results[:errors] << transaction.errors.full_messages.join(', ')
      nil
    end
  end

  # Bulk create transactions without callbacks
  # Note: Does NOT enqueue anomaly detection - caller must do that explicitly
  def create_bulk(transactions_data)
    return [] if transactions_data.empty?

    now = Time.current

    valid_records = transactions_data
      .reject(&method(:invalid_transaction?))
      .map(&method(:prepare_transaction_record).curry.call(now))
      .map(&method(:add_transaction_category))

    return [] if valid_records.empty?

    # Bulk insert - bypasses callbacks for performance
    result = Transaction.insert_all(valid_records, returning: [:id])

    inserted_ids = result.rows.flatten
    results[:success] += inserted_ids.count
    results[:imported_ids].concat(inserted_ids)

    inserted_ids
  end

  private

  def invalid_transaction?(data)
    if data[:date].blank?
      row_summary = "description: \"#{data[:description]}\", amount: #{data[:amount]}, category: \"#{data[:category]}\""
      results[:errors] << "Missing date - Row data: #{row_summary}"
      return true
    end

    if data[:amount].blank?
      row_summary = "date: \"#{data[:date]}\", description: \"#{data[:description]}\", category: \"#{data[:category]}\""
      results[:errors] << "Missing amount - Row data: #{row_summary}"
      return true
    end

    false
  end

  def prepare_transaction_record(now, data)
    # Manually normalize and generate hash (since callbacks won't run)
    data.merge(
      description: StringUtils.clean_spaces(data[:description]),
      description_hash: StringUtils.normalize_and_hash(data[:description]),
      status: 0, # pending
      flagged: false,
      created_at: now,
      updated_at: now
    )
  end

  # Find matching category using cached rules (returns Category object)
  def find_matching_category(transaction)
    rule = @categorization_rules.find { _1.matches?(transaction) }
    rule&.category
  end

  def add_transaction_category(data)
    category_name = data[:category]
    category_id = nil
    
    if category_name.blank?
      # Try to match using categorization rules
      temp_transaction = Transaction.new(
        date: data[:date],
        description: data[:description],
        amount: data[:amount]
      )
      category = find_matching_category(temp_transaction)
      category_id = category&.id
    else
      # Find or create category by name from CSV
      category = Category.find_or_create_by!(name: category_name)
      category_id = category.id
    end
    
    data.except(:category).merge(category_id: category_id)
  end

  # Class method for convenience
  def self.create_single(attributes)
    service = new
    transaction = service.create_single(attributes)
    [transaction, service.results]
  end

  def self.create_bulk(transactions_data)
    service = new
    ids = service.create_bulk(transactions_data)
    [ids, service.results]
  end
end

