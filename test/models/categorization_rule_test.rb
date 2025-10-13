require "test_helper"

class CategorizationRuleTest < ActiveSupport::TestCase
  # Validation Tests
  test "should require name" do
    rule = build(:categorization_rule, name: nil)
    assert_not rule.valid?
    assert_includes rule.errors[:name], "can't be blank"
  end

  test "should require category" do
    rule = build(:categorization_rule, category: nil)
    assert_not rule.valid?
    assert_includes rule.errors[:category], "must exist"
  end

  test "should require priority to be an integer" do
    rule = build(:categorization_rule, priority: "abc")
    assert_not rule.valid?
    assert_includes rule.errors[:priority], "is not a number"
  end

  test "should require priority to be greater than or equal to 0" do
    rule = build(:categorization_rule, priority: -1)
    assert_not rule.valid?
    assert_includes rule.errors[:priority], "must be greater than or equal to 0"
  end

  test "description_contains rule should require pattern" do
    rule = build(:categorization_rule, rule_type: :description_contains, pattern: nil)
    assert_not rule.valid?
    assert_includes rule.errors[:pattern], "can't be blank for description_contains rule"
  end

  test "amount_threshold rule should require threshold in conditions" do
    rule = build(:categorization_rule, rule_type: :amount_threshold, conditions: {})
    assert_not rule.valid?
    assert_includes rule.errors[:conditions], "must include 'threshold' for amount_threshold rule"
  end

  test "date_range rule should require start_date and end_date in conditions" do
    rule = build(:categorization_rule, rule_type: :date_range, conditions: { "start_date" => "2024-01-01" })
    assert_not rule.valid?
    assert_includes rule.errors[:conditions], "must include 'start_date' and 'end_date' for date_range rule"
  end

  # Scope Tests
  test "active scope should return only active rules" do
    active_rule = create(:categorization_rule, active: true)
    inactive_rule = create(:categorization_rule, active: false)
    
    assert_includes CategorizationRule.active, active_rule
    assert_not_includes CategorizationRule.active, inactive_rule
  end

  test "ordered scope should order by priority descending then created_at descending" do
    rule1 = create(:categorization_rule, priority: 10, created_at: 2.days.ago)
    rule2 = create(:categorization_rule, priority: 20, created_at: 1.day.ago)
    rule3 = create(:categorization_rule, priority: 10, created_at: 1.day.ago)
    
    ordered = CategorizationRule.ordered.to_a
    assert_equal rule2, ordered[0], "Highest priority should be first"
    assert_equal rule3, ordered[1], "Same priority, more recent created_at should be second"
    assert_equal rule1, ordered[2], "Lowest priority/oldest should be last"
  end

  # Description Contains Matching Tests
  test "description_contains should match case-insensitively" do
    rule = create(:categorization_rule, 
      rule_type: :description_contains, 
      pattern: "amazon",
      active: true
    )
    transaction = create(:transaction, description: "AMAZON PURCHASE")
    
    assert rule.matches?(transaction)
  end

  test "description_contains should match partial string" do
    rule = create(:categorization_rule, 
      rule_type: :description_contains, 
      pattern: "grocery",
      active: true
    )
    transaction = create(:transaction, description: "Local Grocery Store Purchase")
    
    assert rule.matches?(transaction)
  end

  test "description_contains should not match when pattern not in description" do
    rule = create(:categorization_rule, 
      rule_type: :description_contains, 
      pattern: "walmart",
      active: true
    )
    transaction = create(:transaction, description: "Target Purchase")
    
    assert_not rule.matches?(transaction)
  end

  test "description_contains should not match when pattern is blank" do
    rule = build(:categorization_rule, 
      rule_type: :description_contains, 
      pattern: "",
      active: true
    )
    rule.save(validate: false) # Force save to test runtime behavior
    transaction = create(:transaction, description: "Something")
    
    assert_not rule.matches?(transaction)
  end

  test "description_contains should not match when description is blank" do
    rule = create(:categorization_rule, 
      rule_type: :description_contains, 
      pattern: "amazon",
      active: true
    )
    transaction = build(:transaction, description: nil)
    transaction.save(validate: false) # Force save to test runtime behavior
    
    assert_not rule.matches?(transaction)
  end

  # Amount Threshold Matching Tests
  test "amount_threshold should match with > operator" do
    rule = create(:categorization_rule,
      rule_type: :amount_threshold,
      conditions: { "operator" => ">", "threshold" => "100" },
      active: true
    )
    
    transaction_match = create(:transaction, amount: 150)
    transaction_no_match = create(:transaction, amount: 50)
    
    assert rule.matches?(transaction_match)
    assert_not rule.matches?(transaction_no_match)
  end

  test "amount_threshold should match with >= operator" do
    rule = create(:categorization_rule,
      rule_type: :amount_threshold,
      conditions: { "operator" => ">=", "threshold" => "100" },
      active: true
    )
    
    transaction_equal = create(:transaction, amount: 100)
    transaction_greater = create(:transaction, amount: 150)
    transaction_less = create(:transaction, amount: 50)
    
    assert rule.matches?(transaction_equal)
    assert rule.matches?(transaction_greater)
    assert_not rule.matches?(transaction_less)
  end

  test "amount_threshold should match with < operator" do
    rule = create(:categorization_rule,
      rule_type: :amount_threshold,
      conditions: { "operator" => "<", "threshold" => "100" },
      active: true
    )
    
    transaction_match = create(:transaction, amount: 50)
    transaction_no_match = create(:transaction, amount: 150)
    
    assert rule.matches?(transaction_match)
    assert_not rule.matches?(transaction_no_match)
  end

  test "amount_threshold should match with <= operator" do
    rule = create(:categorization_rule,
      rule_type: :amount_threshold,
      conditions: { "operator" => "<=", "threshold" => "100" },
      active: true
    )
    
    transaction_equal = create(:transaction, amount: 100)
    transaction_less = create(:transaction, amount: 50)
    transaction_greater = create(:transaction, amount: 150)
    
    assert rule.matches?(transaction_equal)
    assert rule.matches?(transaction_less)
    assert_not rule.matches?(transaction_greater)
  end

  test "amount_threshold should match with == operator" do
    rule = create(:categorization_rule,
      rule_type: :amount_threshold,
      conditions: { "operator" => "==", "threshold" => "100" },
      active: true
    )
    
    transaction_match = create(:transaction, amount: 100)
    transaction_no_match = create(:transaction, amount: 150)
    
    assert rule.matches?(transaction_match)
    assert_not rule.matches?(transaction_no_match)
  end

  test "amount_threshold should not match with invalid operator" do
    rule = build(:categorization_rule,
      rule_type: :amount_threshold,
      conditions: { "operator" => "!=", "threshold" => "100" },
      active: true
    )
    rule.save(validate: false) # Force save to test runtime behavior
    transaction = create(:transaction, amount: 150)
    
    assert_not rule.matches?(transaction)
  end

  # Date Range Matching Tests
  test "date_range should match date within range" do
    rule = create(:categorization_rule,
      rule_type: :date_range,
      conditions: { 
        "start_date" => "2024-01-01", 
        "end_date" => "2024-12-31" 
      },
      active: true
    )
    
    transaction_in_range = create(:transaction, date: Date.parse("2024-06-15"))
    transaction_out_range = create(:transaction, date: Date.parse("2025-01-15"))
    
    assert rule.matches?(transaction_in_range)
    assert_not rule.matches?(transaction_out_range)
  end

  test "date_range should match date on boundary" do
    rule = create(:categorization_rule,
      rule_type: :date_range,
      conditions: { 
        "start_date" => "2024-01-01", 
        "end_date" => "2024-12-31" 
      },
      active: true
    )
    
    transaction_start = create(:transaction, date: Date.parse("2024-01-01"))
    transaction_end = create(:transaction, date: Date.parse("2024-12-31"))
    
    assert rule.matches?(transaction_start)
    assert rule.matches?(transaction_end)
  end

  test "date_range should not match with invalid date format" do
    rule = build(:categorization_rule,
      rule_type: :date_range,
      conditions: { 
        "start_date" => "invalid", 
        "end_date" => "2024-12-31" 
      },
      active: true
    )
    rule.save(validate: false) # Force save to test runtime behavior
    transaction = create(:transaction, date: Date.parse("2024-06-15"))
    
    assert_not rule.matches?(transaction)
  end

  # Active/Inactive Tests
  test "inactive rule should not match any transactions" do
    rule = create(:categorization_rule,
      rule_type: :description_contains,
      pattern: "amazon",
      active: false
    )
    transaction = create(:transaction, description: "amazon purchase")
    
    assert_not rule.matches?(transaction)
  end

  # Apply to Transactions Tests
  test "apply_to_transactions should categorize matching uncategorized transactions" do
    shopping_category = create(:category, :shopping)
    entertainment_category = create(:category, name: 'Entertainment')
    
    rule = create(:categorization_rule,
      rule_type: :description_contains,
      pattern: "amazon",
      category: shopping_category,
      active: true
    )
    
    matching_transaction = create(:transaction, description: "amazon purchase", category: nil)
    non_matching_transaction = create(:transaction, description: "grocery store", category: nil)
    already_categorized = create(:transaction, description: "amazon prime", category: entertainment_category)
    
    count = rule.apply_to_transactions
    
    assert_equal 1, count
    assert_equal shopping_category.id, matching_transaction.reload.category_id
    assert_nil non_matching_transaction.reload.category_id
    assert_equal entertainment_category.id, already_categorized.reload.category_id
  end

  test "apply_all_rules should apply rules in priority order" do
    shopping_category = create(:category, :shopping)
    food_category = create(:category, :food)
    
    # Lower priority rule
    rule1 = create(:categorization_rule,
      rule_type: :description_contains,
      pattern: "store",
      category: shopping_category,
      priority: 5,
      active: true
    )
    
    # Higher priority rule
    rule2 = create(:categorization_rule,
      rule_type: :description_contains,
      pattern: "grocery",
      category: food_category,
      priority: 10,
      active: true
    )
    
    transaction = create(:transaction, description: "grocery store", category: nil)
    
    CategorizationRule.apply_all_rules
    
    # Should be categorized by higher priority rule first
    assert_equal food_category.id, transaction.reload.category_id
  end

  test "apply_all_rules should only apply active rules" do
    shopping_category = create(:category, :shopping)
    online_category = create(:category, name: 'Online')
    
    active_rule = create(:categorization_rule,
      rule_type: :description_contains,
      pattern: "amazon",
      category: shopping_category,
      active: true
    )
    
    inactive_rule = create(:categorization_rule,
      rule_type: :description_contains,
      pattern: "amazon",
      category: online_category,
      active: false
    )
    
    transaction = create(:transaction, description: "amazon purchase", category: nil)
    
    CategorizationRule.apply_all_rules
    
    assert_equal shopping_category.id, transaction.reload.category_id
  end
end
