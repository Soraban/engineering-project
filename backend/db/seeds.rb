# Create default categories
puts "Creating default categories..."

Category.default_categories.each do |category_attrs|
  Category.find_or_create_by!(name: category_attrs[:name]) do |category|
    category.color = category_attrs[:color]
  end
end

puts "✓ Created #{Category.count} categories"

# Create some default rules
puts "Creating default rules..."

shopping_category = Category.find_by(name: 'Shopping')
food_category = Category.find_by(name: 'Food & Dining')
transportation_category = Category.find_by(name: 'Transportation')
high_value_category = Category.find_by(name: 'High Value')

rules_data = [
  {
    name: 'Amazon purchases',
    condition_type: 'description_contains',
    condition_value: 'amazon',
    action_type: 'categorize',
    category: shopping_category,
    priority: 10
  },
  {
    name: 'Restaurant transactions',
    condition_type: 'description_contains',
    condition_value: 'restaurant',
    action_type: 'categorize',
    category: food_category,
    priority: 10
  },
  {
    name: 'Uber/Lyft rides',
    condition_type: 'description_contains',
    condition_value: 'uber',
    action_type: 'categorize',
    category: transportation_category,
    priority: 10
  },
  {
    name: 'High value transactions',
    condition_type: 'amount_greater_than',
    condition_value: '1000',
    action_type: 'categorize',
    category: high_value_category,
    priority: 5
  },
  {
    name: 'Flag large transactions',
    condition_type: 'amount_greater_than',
    condition_value: '5000',
    action_type: 'flag',
    action_value: 'Large transaction - requires review',
    priority: 20
  }
]

rules_data.each do |rule_attrs|
  Rule.find_or_create_by!(name: rule_attrs[:name]) do |rule|
    rule.condition_type = rule_attrs[:condition_type]
    rule.condition_value = rule_attrs[:condition_value]
    rule.action_type = rule_attrs[:action_type]
    rule.action_value = rule_attrs[:action_value]
    rule.category = rule_attrs[:category]
    rule.priority = rule_attrs[:priority]
  end
end

puts "✓ Created #{Rule.count} rules"

# Create sample transactions (optional - uncomment if needed)
# puts "Creating sample transactions..."
#
# 50.times do
#   Transaction.create!(
#     transaction_date: rand(90.days).seconds.ago,
#     description: ["Amazon.com", "Whole Foods", "Uber", "Netflix", "Starbucks"].sample,
#     amount: rand(10.0..500.0).round(2)
#   )
# end
#
# puts "✓ Created #{Transaction.count} sample transactions"

puts "\n✅ Database seeded successfully!"
