# app/models/transaction.rb
class Transaction < ApplicationRecord
    belongs_to :category, optional: true
  
    validates :date, presence: true
    validates :amount, presence: true, numericality: true
    
    # Scopes
    scope :uncategorized, -> { where(category_id: nil) }
    scope :flagged, -> { where(flagged: true) }
    
    # Method to apply rules
    def apply_rules
      Rule.all.each do |rule|
        if matches_rule?(rule)
          self.category_id = rule.category_id
          save
          break
        end
      end
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
      case rule.condition_operator
      when 'contains'
        description&.include?(rule.condition_value)
      when 'equals'
        description == rule.condition_value
      else
        false
      end
    end
    
    def matches_amount_rule?(rule)
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