class CategorizationRule < ApplicationRecord
  # Associations
  belongs_to :category

  # Enums
  enum :rule_type, {
    description_contains: 0,
    amount_threshold: 1,
    date_range: 2
  }

  # Validations
  validates :name, presence: true
  validates :priority, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :validate_rule_conditions

  # Scopes (only actively used ones)
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(priority: :desc, created_at: :desc) }

  VALID_OPERATORS = %w[> >= < <= ==]

  def matches?(transaction)
    return false unless active?

    if description_contains?
      match_description_contains?(transaction)
    elsif amount_threshold?
      match_amount_threshold?(transaction)
    elsif date_range?
      match_date_range?(transaction)
    else
      false
    end
  end

  def apply_to_transactions
    count = 0

    Transaction.uncategorized.find_each do |transaction|
      if matches?(transaction)
        transaction.update_column(:category_id, category_id)
        count += 1
      end
    end

    count
  end

  def self.apply_all_rules
    active.ordered.each do |rule|
      rule.apply_to_transactions
    end
  end

  private

  def match_description_contains?(transaction)
    return false if pattern.blank? || transaction.description.blank?
    transaction.description.downcase.include?(pattern.downcase)
  end

  def match_amount_threshold?(transaction)
    return false unless conditions.is_a?(Hash)
    
    operator = conditions['operator']
    threshold = conditions['threshold'].to_f
    
    return false unless VALID_OPERATORS.include?(operator)
    
    transaction.amount.send(operator, threshold)
  end

  def match_date_range?(transaction)
    return false unless conditions.is_a?(Hash)

    start_date = Date.parse(conditions['start_date']) rescue nil
    end_date = Date.parse(conditions['end_date']) rescue nil

    return false if start_date.nil? || end_date.nil?

    transaction.date.between?(start_date, end_date)
  end

  def validate_rule_conditions
    return if rule_type.nil?

    if description_contains?
      errors.add(:pattern, "can't be blank for description_contains rule") if pattern.blank?
    elsif amount_threshold?
      unless conditions.is_a?(Hash) && conditions['threshold'].present?
        errors.add(:conditions, "must include 'threshold' for amount_threshold rule")
      end
    elsif date_range?
      unless conditions.is_a?(Hash) && conditions['start_date'].present? && conditions['end_date'].present?
        errors.add(:conditions, "must include 'start_date' and 'end_date' for date_range rule")
      end
    end
  end
end
