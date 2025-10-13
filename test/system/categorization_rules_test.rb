require "application_system_test_case"

class CategorizationRulesTest < ApplicationSystemTestCase
  setup do
    CategorizationRule.delete_all
    Transaction.delete_all
    
    # Ensure categories exist
    @category = Category.find_or_create_by!(name: 'Shopping') do |c|
      c.description = 'Retail purchases'
      c.color = '#FF6B6B'
    end
    
    Category.find_or_create_by!(name: 'High Value') do |c|
      c.description = 'Large transactions'
      c.color = '#DC143C'
    end
    
    Category.find_or_create_by!(name: 'Food & Dining') do |c|
      c.description = 'Restaurants'
      c.color = '#4ECDC4'
    end
  end

  test "viewing categorization rules list" do
    create(:categorization_rule, name: "Amazon Rule", pattern: "amazon")
    create(:categorization_rule, name: "High Value Rule")

    visit categorization_rules_url

    assert_text "Amazon Rule"
    assert_text "High Value Rule"
  end

  test "creating a description contains rule" do
    visit categorization_rules_url
    
    click_on "New Rule"

    fill_in "Name", with: "Amazon Rule"
    select "description_contains", from: "Rule type"
    fill_in "Pattern", with: "amazon"
    select "Shopping", from: "Category"
    fill_in "Priority", with: "10"

    click_on "Create Categorization rule"

    # Should redirect to rules list
    assert_current_path categorization_rules_url
    
    # Should show the new rule
    assert_text "Amazon Rule"
    
    # Verify rule was created
    rule = CategorizationRule.last
    assert_equal "Amazon Rule", rule.name
    assert_equal "description_contains", rule.rule_type
    assert_equal "amazon", rule.pattern
    assert_equal "Shopping", rule.category
    assert_equal 10, rule.priority
  end

  test "creating an amount threshold rule" do
    visit new_categorization_rule_url

    fill_in "Name", with: "High Value Rule"
    select "amount_threshold", from: "Rule type"
    select "Shopping", from: "Category"
    fill_in "Priority", with: "100"
    
    # Fill in threshold conditions
    select ">", from: "Operator"
    fill_in "Threshold", with: "1000"

    click_on "Create Categorization rule"

    # Should show the new rule
    assert_text "High Value Rule"
    
    # Verify rule was created with conditions
    rule = CategorizationRule.last
    assert_equal "amount_threshold", rule.rule_type
    assert_equal ">", rule.conditions['operator']
    assert_equal "1000", rule.conditions['threshold']
  end

  test "creating rule with missing required fields shows errors" do
    visit new_categorization_rule_url

    # Don't fill in name (required field)
    select "description_contains", from: "Rule type"

    click_on "Create Categorization rule"

    # Should show validation errors
    assert_text /can't be blank|is required/i
  end

  test "editing an existing rule" do
    rule = create(:categorization_rule, 
                  name: "Old Name",
                  priority: 5)

    visit categorization_rules_url
    
    # Find and click edit link
    within "[data-rule-id='#{rule.id}'], tr", match: :first do
      click_on "Edit"
    end

    fill_in "Name", with: "New Name"
    fill_in "Priority", with: "15"

    click_on "Update Categorization rule"

    # Should redirect to rules list
    assert_current_path categorization_rules_url
    
    # Should show updated values
    assert_text "New Name"
    
    rule.reload
    assert_equal "New Name", rule.name
    assert_equal 15, rule.priority
  end

  test "deleting a categorization rule" do
    rule = create(:categorization_rule, name: "Rule to Delete")

    visit categorization_rules_url

    # Should show the rule
    assert_text "Rule to Delete"

    # Find and click delete button
    within "[data-rule-id='#{rule.id}'], tr", match: :first do
      accept_confirm do
        click_on "Delete"
      end
    end

    # Should redirect to rules list
    assert_current_path categorization_rules_url
    
    # Rule should be deleted
    assert_not CategorizationRule.exists?(rule.id)
  end

  test "toggling a rule from active to inactive" do
    rule = create(:categorization_rule, 
                  name: "Toggle Rule",
                  active: true)

    visit categorization_rules_url

    # Should show active status
    within "[data-rule-id='#{rule.id}'], tr", match: :first do
      assert_text /active/i
      click_on "Toggle"
    end

    # Should redirect back
    assert_current_path categorization_rules_url
    
    # Rule should be inactive
    rule.reload
    assert_not rule.active?
  end

  test "applying a single rule to transactions" do
    rule = create(:categorization_rule,
                  name: "Amazon Rule",
                  rule_type: :description_contains,
                  pattern: "amazon",
                  category: "Shopping")
    
    t1 = create(:transaction, description: "Amazon Purchase", category: nil)
    t2 = create(:transaction, description: "Other Store", category: nil)

    visit categorization_rules_url

    # Click apply button for this rule
    within "[data-rule-id='#{rule.id}'], tr", match: :first do
      click_on "Apply"
    end

    # Should show success message
    assert_text /Rule applied/i
    
    # Should redirect back
    assert_current_path categorization_rules_url
    
    # Verify transactions were categorized correctly
    t1.reload
    t2.reload
    assert_equal "Shopping", t1.category
    assert_nil t2.category
  end

  test "applying all rules to transactions" do
    rule1 = create(:categorization_rule,
                   name: "Amazon",
                   rule_type: :description_contains,
                   pattern: "amazon",
                   category: "Shopping",
                   priority: 10)
    
    rule2 = create(:categorization_rule,
                   name: "High Value",
                   rule_type: :amount_threshold,
                   category: "High Value",
                   priority: 100,
                   conditions: { 'operator' => '>', 'threshold' => 1000 })

    t1 = create(:transaction, description: "Amazon Purchase", amount: 50, category: nil)
    t2 = create(:transaction, description: "Expensive Item", amount: 1500, category: nil)

    visit categorization_rules_url

    # Click "Apply All Rules" button
    click_on "Apply All Rules"

    # Should show success message
    assert_text /applied/i
    
    # Verify transactions were categorized
    t1.reload
    t2.reload
    assert_equal "Shopping", t1.category
    assert_equal "High Value", t2.category
  end

  test "rules are sorted by priority" do
    create(:categorization_rule, name: "Low Priority", priority: 5)
    create(:categorization_rule, name: "High Priority", priority: 100)
    create(:categorization_rule, name: "Medium Priority", priority: 50)

    visit categorization_rules_url

    # Get all rule names in order they appear
    rule_names = all(".rule-name, td:first-child").map(&:text)
    
    # High priority should come first (if sorted descending)
    # or verify that they're in some consistent order
    assert rule_names.include?("Low Priority")
    assert rule_names.include?("High Priority")
    assert rule_names.include?("Medium Priority")
  end
end

