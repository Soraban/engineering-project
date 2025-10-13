FactoryBot.define do
  factory :transaction do
    date { Date.today }
    description { "Sample transaction" }
    amount { 100.00 }
    category { nil }
    status { :pending }
    flagged { false }

    trait :categorized do
      association :category, factory: [:category, :shopping]
    end

    trait :flagged do
      flagged { true }
    end

    trait :high_value do
      amount { 1500.00 }
    end

    trait :reviewed do
      status { :reviewed }
    end

    trait :with_anomalies do
      after(:create) do |transaction|
        create(:anomaly_flag, transaction_record: transaction)
      end
    end
  end
end

