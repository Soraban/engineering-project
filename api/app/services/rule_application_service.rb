# app/services/rule_application_service.rb
class RuleApplicationService
    # Change to class methods
    def self.apply_rules_to_transaction(transaction)
      # Only proceed if rules exist and category is not already set
      return unless Rule.exists? && transaction.category_id.nil?
      
      # Get all rules, ordered by priority if the column exists
      rules = if Rule.column_names.include?('priority')
                Rule.order(priority: :desc)
              else
                Rule.all
              end
      
      rules.each do |rule|
        if transaction.matches_rule?(rule)
          transaction.update(category_id: rule.category_id)
          # Add a record of the rule application if you're tracking that
          transaction.rule_applications.create(rule: rule) if defined?(RuleApplication)
          break # Stop after first match
        end
      end
    end
  
    def self.apply_rule_to_all_transactions(rule_id)
      rule = Rule.find(rule_id)
      
      # Process in batches for performance
      Transaction.find_in_batches(batch_size: 1000) do |batch|
        batch.each do |transaction|
          if transaction.matches_rule?(rule) && transaction.category_id.nil?
            transaction.update(category_id: rule.category_id)
            # Add a record of the rule application if you're tracking that
            transaction.rule_applications.create(rule: rule) if defined?(RuleApplication)
          end
        end
      end
    end
  end