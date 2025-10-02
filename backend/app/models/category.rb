class Category < ApplicationRecord
  has_many :transactions
  has_many :rules

  validates :name, presence: true, uniqueness: true

  def self.default_categories
    [
      { name: 'Shopping', color: '#FF6B6B' },
      { name: 'Food & Dining', color: '#4ECDC4' },
      { name: 'Transportation', color: '#45B7D1' },
      { name: 'Utilities', color: '#FFA07A' },
      { name: 'Entertainment', color: '#98D8C8' },
      { name: 'Healthcare', color: '#FF7979' },
      { name: 'Income', color: '#6BCF7F' },
      { name: 'High Value', color: '#F38181' },
      { name: 'Uncategorized', color: '#95A5A6' }
    ]
  end
end
