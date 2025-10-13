FactoryBot.define do
  factory :categorization_rule do
    sequence(:name) { |n| "Rule #{n}" }
    rule_type { :description_contains }
    pattern { "test" }
    association :category
    priority { 10 }
    active { true }
    conditions { {} }

    trait :amount_threshold do
      rule_type { :amount_threshold }
      pattern { "" }
      conditions { { 'operator' => '>', 'threshold' => 1000 } }
    end

    trait :date_range do
      rule_type { :date_range }
      pattern { "" }
      conditions { { 'start_date' => '2024-01-01', 'end_date' => '2024-12-31' } }
    end

    trait :inactive do
      active { false }
    end
  end
end

