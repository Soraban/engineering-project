class ApplyRuleToExistingTransactionsJob < ApplicationJob
    queue_as :default
  
    def perform(rule_id)
      RuleApplicationService.apply_rule_to_all_transactions(rule_id)
    end
  end