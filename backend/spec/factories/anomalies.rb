FactoryBot.define do
  factory :anomaly do
    bookkeeping_transaction factory: :transaction
    anomaly_type  { 'unusual_amount' }
    severity      { 'medium' }
    details       { { 'std_devs_above_mean' => 4.2 } }
    explanation   { nil }
    resolved      { false }
  end
end
