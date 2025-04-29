class RuleApplication < ApplicationRecord
    belongs_to :transaction_record, class_name: 'Transaction', foreign_key: 'transaction_id'
    belongs_to :rule
    
    validates :transaction_id, uniqueness: { scope: :rule_id }
  end