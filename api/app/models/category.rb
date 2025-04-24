class Category < ApplicationRecord
    has_many :transactions
    has_many :rules
    
    validates :name, presence: true, uniqueness: true
  end