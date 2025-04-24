# app/models/rule.rb
class Rule < ApplicationRecord
    belongs_to :category
    
    validates :condition_field, presence: true
    validates :condition_operator, presence: true
    validates :condition_value, presence: true
    
    # Available condition fields
    CONDITION_FIELDS = ['description', 'amount']
    
    # Available operators for each field
    OPERATORS = {
      'description' => ['contains', 'equals'],
      'amount' => ['>', '<', '=']
    }
    
    validate :valid_condition
    
    private
    
    def valid_condition
      unless CONDITION_FIELDS.include?(condition_field)
        errors.add(:condition_field, "must be one of: #{CONDITION_FIELDS.join(', ')}")
      end
      
      unless OPERATORS[condition_field]&.include?(condition_operator)
        errors.add(:condition_operator, "must be one of: #{OPERATORS[condition_field]&.join(', ')}")
      end
    end
  end