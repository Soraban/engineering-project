class Rule < ApplicationRecord
  belongs_to :category, optional: true

  validates :name, presence: true
  validates :condition_type, presence: true, inclusion: {
    in: %w[description_contains amount_greater_than amount_less_than amount_equals]
  }
  validates :condition_value, presence: true
  validates :action_type, presence: true, inclusion: { in: %w[categorize flag] }

  scope :active, -> { where(active: true).order(priority: :desc) }

  def matches?(transaction)
    case condition_type
    when 'description_contains'
      transaction.description&.downcase&.include?(condition_value.downcase)
    when 'amount_greater_than'
      transaction.amount > condition_value.to_f
    when 'amount_less_than'
      transaction.amount < condition_value.to_f
    when 'amount_equals'
      transaction.amount == condition_value.to_f
    else
      false
    end
  end

  def apply_to(transaction)
    return unless matches?(transaction)

    case action_type
    when 'categorize'
      transaction.update(category: category) if category
    when 'flag'
      transaction.update(
        flagged_as_anomaly: true,
        anomaly_reason: action_value || "Matched rule: #{name}"
      )
    end
  end
end
