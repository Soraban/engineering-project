# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding default categories..."
default_categories = [
  { name: 'Shopping', description: 'Retail purchases', color: '#FF6B6B' },
  { name: 'Food & Dining', description: 'Restaurants and groceries', color: '#4ECDC4' },
  { name: 'Transportation', description: 'Travel and commute', color: '#45B7D1' },
  { name: 'Utilities', description: 'Bills and services', color: '#FFA07A' },
  { name: 'Entertainment', description: 'Fun and leisure', color: '#98D8C8' },
  { name: 'Healthcare', description: 'Medical expenses', color: '#F67280' },
  { name: 'High Value', description: 'Large transactions', color: '#DC143C' },
  { name: 'Uncategorized', description: 'Needs categorization', color: '#CCCCCC' }
]

default_categories.each do |attrs|
  Category.find_or_create_by(name: attrs[:name]) do |category|
    category.description = attrs[:description]
    category.color = attrs[:color]
  end
end

puts "Creating sample categorization rules..."

shopping_category = Category.find_by(name: 'Shopping')
high_value_category = Category.find_by(name: 'High Value')
food_category = Category.find_by(name: 'Food & Dining')

CategorizationRule.find_or_create_by!(name: 'Amazon Purchases') do |rule|
  rule.rule_type = :description_contains
  rule.pattern = 'amazon'
  rule.category = shopping_category
  rule.priority = 10
  rule.active = true
end

CategorizationRule.find_or_create_by!(name: 'High Value Transactions') do |rule|
  rule.rule_type = :amount_threshold
  rule.pattern = ''
  rule.category = high_value_category
  rule.priority = 100
  rule.active = true
  rule.conditions = { 'operator' => '>', 'threshold' => 1000 }
end

CategorizationRule.find_or_create_by!(name: 'Restaurant Spending') do |rule|
  rule.rule_type = :description_contains
  rule.pattern = 'restaurant'
  rule.category = food_category
  rule.priority = 5
  rule.active = true
end

puts "Seed data created successfully!"
