require 'csv'
require 'ruby_like_clojure'

class TransactionCsvParser
  attr_reader :file_path

  def initialize(file_path)
    @file_path = file_path
  end

  # Iterator pattern - yields batches of transaction data
  # Caller is responsible for importing and checkpoint management
  def each_batch(batch_size: 1000, start_offset: 0)
    validate_file!
    
    current_offset = start_offset
    
    CSV.open(file_path, headers: true, header_converters: :symbol)
       .lazy
       .drop(start_offset)  # Resume from checkpoint
       .each_slice(batch_size)
       .each_with_index do |batch, batch_index|
         # Transform batch to transaction data
         batch_data = batch
           .reject(&method(:row_empty?))
           .map(&method(:extract_transaction_data))
         
         # Yield data and current offset to caller
         yield batch_data, current_offset, batch.size
         
         # Update offset after yielding
         current_offset += batch.size
       end
       
  rescue CSV::MalformedCSVError => e
    raise "Malformed CSV file: #{e.message}"
  end

  private

  def validate_file!
    unless File.exist?(file_path)
      raise "File not found: #{file_path}"
    end

    unless File.extname(file_path).downcase == '.csv'
      raise "File must be a CSV file"
    end

    if File.zero?(file_path)
      raise "File is empty"
    end
  end

  def row_empty?(row)
    row.to_h.values.all? { |v| v.nil? || v.to_s.strip.empty? }
  end

  def extract_transaction_data(row)
    {
      date: parse_date(row[:date]),
      description: StringUtils.clean_spaces(row[:description]),
      amount: parse_amount(row[:amount]),
      category: StringUtils.clean_spaces(row[:category])
    }
  end

  def parse_date(date_string)
    return nil if date_string.nil? || date_string.to_s.strip.empty?
    
    date_str = date_string.to_s.strip
    
    # Try multiple date formats
    formats = [
      '%Y-%m-%d',      # 2024-01-15
      '%m/%d/%Y',      # 01/15/2024
      '%d/%m/%Y',      # 15/01/2024
      '%Y/%m/%d',      # 2024/01/15
      '%m-%d-%Y',      # 01-15-2024
      '%d-%m-%Y',      # 15-01-2024
      '%b %d, %Y',     # Jan 15, 2024
      '%B %d, %Y',     # January 15, 2024
      '%Y%m%d'         # 20240115
    ]
    
    formats.each do |format|
      begin
        return Date.strptime(date_str, format)
      rescue ArgumentError
        next
      end
    end
    
    # Fallback to Date.parse for flexible parsing
    begin
      Date.parse(date_str)
    rescue ArgumentError, TypeError
      nil
    end
  end

  def parse_amount(amount_value)
    return nil if amount_value.nil? || amount_value.to_s.strip.empty?
    
    amount_str = amount_value.to_s.strip
    
    # Remove currency symbols and commas
    cleaned = amount_str.gsub(/[$,€£¥]/, '').strip
    
    # Handle negative amounts in parentheses (accounting format)
    if cleaned.match?(/^\(.*\)$/)
      cleaned = "-#{cleaned.gsub(/[()]/, '')}"
    end
    
    # Convert to float
    Float(cleaned) rescue nil
  end

  # Class method for convenience - processes all batches and returns results
  def self.parse(file_path, start_offset: 0)
    parser = new(file_path)
    results = { success: 0, errors: [], imported_ids: [] }
    
    parser.each_batch(start_offset: start_offset) do |batch_data, offset, batch_size|
      next if batch_data.empty?
      
      service = TransactionCreationService.new
      Transaction.transaction do
        service.create_bulk(batch_data)
      end
      
      results[:success] += service.results[:success]
      results[:errors].concat(service.results[:errors])
      results[:imported_ids].concat(service.results[:imported_ids])
    end
    
    results
  end
end

