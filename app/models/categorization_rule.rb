class CategorizationRule < ApplicationRecord
  validates :pattern, presence: true
  validates :category, presence: true
  validates :active, inclusion: { in: [ true, false ] }
end
