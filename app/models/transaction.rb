class Transaction < ApplicationRecord
  validates :date, presence: true
  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :category, presence: true, allow_blank: true
end
