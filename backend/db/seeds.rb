require 'faker'

puts "Seeding database..."

# Create demo user
user = User.find_or_create_by!(email: 'demo@test.com') do |u|
  u.password = 'password123'
end

puts "Created user: #{user.email}"

# Skip bulk seeding if the demo user already has transactions (idempotent across deploys)
if Transaction.where(user: user).count >= 10_000
  puts "Already seeded (#{Transaction.where(user: user).count} transactions) — skipping"
  exit 0
end

# Categories for transactions
categories = ['Shopping', 'Food & Dining', 'Entertainment', 'Housing', 'Transportation',
              'Utilities', 'Healthcare', 'Travel', 'Education', 'Subscriptions', nil]

merchants = {
  'Shopping' => ['Amazon Purchase', 'AMAZON MKTP US*2F4KL9', 'Target', 'Walmart', 'Best Buy', 'AMZN MKTP US'],
  'Food & Dining' => ['Starbucks', 'Starbucks #1204', 'Chipotle', 'Whole Foods', 'DoorDash', 'Uber Eats'],
  'Entertainment' => ['Netflix', 'Spotify', 'Hulu', 'Disney+', 'AMC Theaters', 'Steam Games'],
  'Housing' => ['Rent Payment', 'Monthly Lease Payment', 'Home Depot', 'Lowes'],
  'Transportation' => ['Shell Gas', 'Uber', 'Lyft', 'Chevron', 'Public Transit'],
  'Utilities' => ['PG&E Electric', 'AT&T Wireless', 'Comcast Internet', 'Water Bill'],
  'Healthcare' => ['CVS Pharmacy', 'Kaiser Permanente', 'Walgreens'],
  'Travel' => ['Delta Airlines', 'Marriott Hotel', 'Airbnb', 'Hertz Car Rental'],
  'Education' => ['Udemy Course', 'Coursera', 'Book Purchase'],
  'Subscriptions' => ['Adobe CC', 'GitHub Pro', 'Figma', 'Notion', 'Slack'],
}

# Generate 10,000+ transactions spread across 12 months
puts "Generating 10,000 transactions..."
records = []
10_000.times do |i|
  category = categories.sample
  desc = if category && merchants[category]
           merchants[category].sample
         else
           [Faker::Commerce.product_name, nil, ''].sample
         end

  date = Faker::Date.between(from: 12.months.ago, to: Date.today)
  amount = case category
           when 'Housing' then rand(1500..3000).to_f
           when 'Travel' then rand(100..2000).to_f
           when 'Subscriptions' then rand(5..50).to_f
           when 'Food & Dining' then rand(5..80).to_f
           else rand(5..500).to_f
           end

  records << {
    user_id: user.id,
    date: date,
    description: desc,
    description_normalized: Transaction.normalize_description(desc),
    amount: amount,
    category: category,
    status: 'pending',
    source: 'csv',
    anomaly_flags: [],
    metadata: {},
    created_at: Time.current,
    updated_at: Time.current
  }
end

# Insert in batches
records.each_slice(1000) do |batch|
  Transaction.insert_all(batch)
end
puts "Created #{Transaction.count} transactions"

# Create some deliberate duplicates
5.times do
  date = Faker::Date.between(from: 3.months.ago, to: Date.today)
  2.times do
    Transaction.create!(
      user: user, date: date, amount: 49.99,
      description: 'Amazon Purchase', status: 'pending', source: 'csv'
    )
  end
end
puts "Added duplicate transactions"

# Create some high-value anomalies
5.times do
  Transaction.create!(
    user: user,
    date: Faker::Date.between(from: 1.month.ago, to: Date.today),
    amount: rand(5000..15000),
    description: ['Wire Transfer', 'Large Purchase', nil].sample,
    status: 'pending',
    source: 'manual'
  )
end
puts "Added high-value transactions"

# Create rules
rules = [
  { name: 'Amazon → Shopping', condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'amazon' },
    action: { 'type' => 'set_category', 'value' => 'Shopping' }, priority: 1, continue_processing: true },
  { name: 'Starbucks → Food', condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'starbucks' },
    action: { 'type' => 'set_category', 'value' => 'Food & Dining' }, priority: 2 },
  { name: 'High Value Flag', condition: { 'field' => 'amount', 'operator' => 'gt', 'value' => '5000' },
    action: { 'type' => 'flag_high_value' }, priority: 3 },
  { name: 'Rent → Housing', condition: { 'field' => 'description', 'operator' => 'matches', 'value' => 'rent|lease' },
    action: { 'type' => 'set_category', 'value' => 'Housing' }, priority: 4 },
  { name: 'Subscriptions Tag', condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'netflix' },
    action: { 'type' => 'add_tag', 'value' => 'recurring' }, priority: 5, continue_processing: true },
]

rules.each do |attrs|
  Rule.find_or_create_by!(user: user, name: attrs[:name]) do |r|
    r.assign_attributes(attrs)
  end
end
puts "Created #{Rule.count} rules"

# Run anomaly detection on a sample of transactions
puts "Running anomaly detection on recent transactions..."
Transaction.where(user: user).order(created_at: :desc).limit(100).each do |tx|
  AnomalyDetector.check(tx)
rescue => e
  # Skip errors during seeding
  nil
end

puts "Seeding complete!"
puts "  Transactions: #{Transaction.count}"
puts "  Anomalies: #{Anomaly.count}"
puts "  Rules: #{Rule.count}"
puts "  Flagged: #{Transaction.where(status: 'flagged').count}"
puts "  Uncategorized: #{Transaction.where(category: [nil, '']).count}"
