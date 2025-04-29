class ApplyRuleToExistingTransactionsJob < ApplicationJob
  queue_as :default

  def perform(rule_id)
    rule = Rule.find(rule_id)
    
    # Process in batches for performance
    Transaction.find_in_batches(batch_size: 1000) do |batch|
      batch.each do |transaction|
        if transaction.matches_rule?(rule)
          transaction.update(category_id: rule.category_id)
          # Add a record of the rule application
          transaction.rule_applications.create(rule: rule)
        end
      end
    end
  end
end 