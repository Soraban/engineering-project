FactoryBot.define do
  factory :anomaly_flag do
    association :transaction_record, factory: :transaction
    anomaly_type { "unusual_amount" }
    severity { "medium" }
    resolved { false }
    details { { message: "Test anomaly" } }

    trait :resolved do
      resolved { true }
    end

    trait :duplicate do
      anomaly_type { "potential_duplicate" }
      severity { "high" }
    end

    trait :missing_metadata do
      anomaly_type { "missing_metadata" }
      severity { "low" }
    end

    trait :critical do
      severity { "critical" }
    end
  end
end

