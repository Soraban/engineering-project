class RuleApplication < ApplicationRecord
    belongs_to :transaction
    belongs_to :rule
    
    validates :transaction_id, uniqueness: { scope: :rule_id }
  end