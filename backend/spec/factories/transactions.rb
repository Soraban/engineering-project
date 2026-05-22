FactoryBot.define do
  factory :transaction do
    user
    date        { Faker::Date.between(from: 1.year.ago, to: Date.today) }
    description { Faker::Commerce.product_name }
    amount      { Faker::Commerce.price(range: 5.0..500.0) }
    category    { nil }
    status      { 'pending' }
    source      { 'manual' }
    anomaly_flags { [] }
    metadata    { {} }
  end
end
