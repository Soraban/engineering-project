FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    description { "Test category" }
    color { "#3498db" }

    trait :shopping do
      name { "Shopping" }
      description { "Retail purchases" }
      color { "#FF6B6B" }
    end

    trait :food do
      name { "Food & Dining" }
      description { "Restaurants and groceries" }
      color { "#4ECDC4" }
    end
  end
end

