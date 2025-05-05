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
      @valid_transactions = []
      @invalid_rows = []
    end
  
    def import
      return invalid_file_error unless valid_file?
  
      CSV.foreach(@file.path, headers: true, skip_blanks: true) do |row|
        process_row(row)
      end
  
      bulk_create_transactions if @valid_transactions.any?
  
      @results
    rescue CSV::MalformedCSVError => e
      @results[:errors] << "Malformed CSV file: #{e.message}"
      @results
    end
  
    private
  
    def process_row(row)
      transaction_attrs = {
        date: parse_date(row['date']),
        description: row['description'],
        amount: parse_amount(row['amount']),
        category_id: row['category_id'],
        created_at: Time.current,
        updated_at: Time.current
      }
  
      transaction = Transaction.new(transaction_attrs)
      
      if transaction.valid?
        @valid_transactions << transaction_attrs
      else
        @invalid_rows << { row: $. + 1, errors: transaction.errors.full_messages }
      end
    end
  
    def bulk_create_transactions
      begin
        # Pre-load all rules for efficiency
        rules = Rule.includes(:category).order(priority: :desc)
        
        # Pre-process transactions with rules
        @valid_transactions.each do |transaction_attrs|
          # Find matching rules
          matching_rules = rules.select do |rule|
            case rule.condition_field
            when 'description'
              transaction_attrs[:description].to_s.downcase.include?(rule.condition_value.to_s.downcase) if rule.condition_operator == 'contains'
            when 'amount'
              amount = transaction_attrs[:amount].to_d
              case rule.condition_operator
              when '>'
                amount > rule.condition_value.to_d
              when '<'
                amount < rule.condition_value.to_d
              when '='
                amount == rule.condition_value.to_d
              end
            end
          end

          # Apply first matching rule's category if no category was specified
          if matching_rules.any? && !transaction_attrs[:category_id]
            transaction_attrs[:category_id] = matching_rules.first.category_id
          end
        end

        # Bulk insert transactions
        result = Transaction.insert_all(@valid_transactions, returning: [:id])
        @results[:imported] = result.rows.count
        
        # Create rule applications in bulk
        rule_applications = []
        result.rows.flatten.each_with_index do |transaction_id, index|
          transaction_attrs = @valid_transactions[index]
          rules.each do |rule|
            if transaction_attrs[:description].to_s.downcase.include?(rule.condition_value.to_s.downcase) ||
               (rule.condition_field == 'amount' && 
                case rule.condition_operator
                when '>'
                  transaction_attrs[:amount].to_d > rule.condition_value.to_d
                when '<'
                  transaction_attrs[:amount].to_d < rule.condition_value.to_d
                when '='
                  transaction_attrs[:amount].to_d == rule.condition_value.to_d
                end)
              rule_applications << {
                transaction_id: transaction_id,
                rule_id: rule.id,
                created_at: Time.current,
                updated_at: Time.current
              }
            end
          end
        end

        # Bulk insert rule applications if any
        RuleApplication.insert_all(rule_applications) if rule_applications.any?

      rescue ActiveRecord::RecordInvalid => e
        @results[:errors] << "Bulk creation failed: #{e.message}"
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
