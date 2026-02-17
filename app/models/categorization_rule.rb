class CategorizationRule < ApplicationRecord
  KINDS = %w[description_contains amount_greater_than].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :pattern, presence: true, if: -> { kind == "description_contains" }
  validates :category, presence: true, if: -> { kind == "description_contains" }

  validates :min_amount, presence: true, if: -> { kind == "amount_greater_than" }
end
