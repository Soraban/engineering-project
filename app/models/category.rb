class Category < ApplicationRecord
  # Associations
  has_many :transactions, dependent: :nullify
  has_many :categorization_rules, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :color, format: { with: /\A#[0-9A-F]{6}\z/i, allow_blank: true }

  # Scopes
  scope :ordered, -> { order(:name) }

  def transaction_count
    transactions.count
  end

  def total_amount
    transactions.sum(:amount)
  end
end
