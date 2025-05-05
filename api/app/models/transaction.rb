# app/models/transaction.rb
class Transaction < ApplicationRecord
  belongs_to :category, optional: true
  has_many :rule_applications, dependent: :destroy
  has_many :applied_rules, through: :rule_applications, source: :rule

  validates :date, presence: true
  validates :amount, presence: true, numericality: true
  
  # Scopes
  scope :uncategorized, -> { where(category_id: nil) }
  scope :flagged, -> { where(flagged: true) }
  
  # Make sure new transactions have rules applied after creation
  after_create :apply_rules
  
  # Method to apply rules
  def apply_rules
    RuleApplicationService.apply_rules_to_transaction(self)
  end
  
  # Check if transaction matches a rule
  def matches_rule?(rule)
    case rule.condition_field
    when 'description'
      matches_description_rule?(rule)
    when 'amount'
      matches_amount_rule?(rule)
    else
      false
    end
  end
  
  private
  
  def matches_description_rule?(rule)
    return false if description.blank?
    
    case rule.condition_operator
    when 'contains'
      description.downcase.include?(rule.condition_value.to_s.downcase)
    when 'equals'
      description.downcase == rule.condition_value.to_s.downcase
    else
      false
    end
  end
  
  def matches_amount_rule?(rule)
    return false if amount.blank?
    
    case rule.condition_operator
    when '>'
      amount > rule.condition_value.to_d
    when '<'
      amount < rule.condition_value.to_d
    when '='
      amount == rule.condition_value.to_d
    else
      false
    end
  end
end