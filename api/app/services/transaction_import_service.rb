# app/services/transaction_import_service.rb
class TransactionImportService
    require 'csv'
    
    def initialize(file)
      @file = file
      @results = {
        imported: 0,
        failed: 0,
        errors: []
      }
    end
  
    def import
      return invalid_file_error unless valid_file?
  
      CSV.foreach(@file.path, headers: true, skip_blanks: true) do |row|
        process_row(row)
      end
  
      @results
    rescue CSV::MalformedCSVError => e
      @results[:errors] << "Malformed CSV file: #{e.message}"
      @results
    end
  
    private
  
    def process_row(row)
      transaction = Transaction.new(
        date: parse_date(row['date']),
        description: row['description'],
        amount: parse_amount(row['amount']),
        category_id: row['category_id']
      )
  
      if transaction.save
        transaction.apply_rules
        @results[:imported] += 1
      else
        @results[:failed] += 1
        @results[:errors] << "Row #{$. + 1}: #{transaction.errors.full_messages.join(', ')}"
      end
    end
  
    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string)
    rescue ArgumentError
      nil
    end
  
    def parse_amount(amount_string)
      return nil if amount_string.blank?
      # Remove currency symbols and convert to decimal
      amount_string.gsub(/[^0-9.-]/, '').to_d
    rescue ArgumentError
      nil
    end
  
    def valid_file?
      return false unless @file.present?
      return false unless @file.respond_to?(:path)
      
      # Check if file is a CSV
      File.extname(@file.path).downcase == '.csv'
    end
  
    def invalid_file_error
      @results[:errors] << 'Please upload a valid CSV file'
      @results
    end
  end
  
  # config/routes.rb
  # Add this to your routes.rb inside the API routes
