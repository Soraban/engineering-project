require "test_helper"

class CategorizationRulesControllerTest < ActionDispatch::IntegrationTest
  # CREATE tests
  test "should create categorization rule with valid attributes" do
    shopping_category = create(:category, :shopping)
    
    assert_difference('CategorizationRule.count', 1) do
      post categorization_rules_url, params: {
        categorization_rule: {
          name: 'Amazon Rule',
          rule_type: :description_contains,
          pattern: 'amazon',
          category_id: shopping_category.id,
          priority: 10,
          active: true
        }
      }
    end

    assert_redirected_to categorization_rules_url
    
    rule = CategorizationRule.last
    assert_equal 'Amazon Rule', rule.name
    assert rule.description_contains?
    assert_equal 'amazon', rule.pattern
    assert_equal shopping_category.id, rule.category_id
    assert_equal 10, rule.priority
    assert rule.active?
  end

  test "should create amount threshold rule" do
    high_value_category = create(:category, name: 'High Value', color: '#DC143C')
    
    assert_difference('CategorizationRule.count', 1) do
      post categorization_rules_url, params: {
        categorization_rule: {
          name: 'High Value',
          rule_type: :amount_threshold,
          category_id: high_value_category.id,
          priority: 100,
          active: true,
          conditions: {
            operator: '>',
            threshold: '1000'
          }
        }
      }
    end

    rule = CategorizationRule.last
    assert rule.amount_threshold?
    assert_equal '>', rule.conditions['operator']
    assert_equal '1000', rule.conditions['threshold']
  end

  test "should not create rule with invalid attributes" do
    assert_no_difference('CategorizationRule.count') do
      post categorization_rules_url, params: {
        categorization_rule: {
          name: '',  # Invalid - name required
          rule_type: 'description_contains'
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create description_contains rule without pattern" do
    shopping_category = create(:category, :shopping)
    
    assert_no_difference('CategorizationRule.count') do
      post categorization_rules_url, params: {
        categorization_rule: {
          name: 'Invalid Rule',
          rule_type: :description_contains,
          pattern: '',  # Required for this type
          category_id: shopping_category.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  # UPDATE tests
  test "should update categorization rule" do
    rule = create(:categorization_rule, name: 'Old Name', priority: 5)

    patch categorization_rule_url(rule), params: {
      categorization_rule: {
        name: 'New Name',
        priority: 15
      }
    }

    assert_redirected_to categorization_rules_url
    
    rule.reload
    assert_equal 'New Name', rule.name
    assert_equal 15, rule.priority
  end

  test "should not update rule with invalid data" do
    rule = create(:categorization_rule, name: 'Valid Name')

    patch categorization_rule_url(rule), params: {
      categorization_rule: {
        name: ''  # Invalid - name can't be blank
      }
    }

    assert_response :unprocessable_entity
    rule.reload
    assert_equal 'Valid Name', rule.name  # Unchanged
  end

  # DELETE tests
  test "should destroy categorization rule" do
    rule = create(:categorization_rule)

    assert_difference('CategorizationRule.count', -1) do
      delete categorization_rule_url(rule)
    end

    assert_redirected_to categorization_rules_url
  end

  # TOGGLE tests
  test "should toggle rule from active to inactive" do
    rule = create(:categorization_rule, active: true)

    post toggle_categorization_rule_url(rule)

    rule.reload
    assert_not rule.active?
    assert_redirected_to categorization_rules_url
  end

  test "should toggle rule from inactive to active" do
    rule = create(:categorization_rule, :inactive)

    post toggle_categorization_rule_url(rule)

    rule.reload
    assert rule.active?
  end

  # APPLY tests
  test "should apply single rule to transactions" do
    shopping_category = create(:category, :shopping)
    rule = create(:categorization_rule, 
      rule_type: :description_contains,
      pattern: 'amazon',
      category: shopping_category
    )
    
    t1 = create(:transaction, description: 'Amazon Purchase', category: nil)
    t2 = create(:transaction, description: 'Other Store', category: nil)

    post apply_categorization_rule_url(rule)

    assert_redirected_to categorization_rules_url
    assert_match /Rule applied/, flash[:notice]

    t1.reload
    t2.reload
    assert_equal shopping_category.id, t1.category_id
    assert_nil t2.category_id  # Doesn't match rule
  end

  test "should apply all rules" do
    shopping_category = create(:category, :shopping)
    high_value_category = create(:category, name: 'High Value')
    
    rule1 = create(:categorization_rule,
      name: 'Amazon',
      rule_type: :description_contains,
      pattern: 'amazon',
      category: shopping_category,
      priority: 10
    )
    
    rule2 = create(:categorization_rule,
      name: 'High Value',
      rule_type: 'amount_threshold',
      category: high_value_category,
      priority: 100,
      conditions: { 'operator' => '>', 'threshold' => 1000 }
    )

    t1 = create(:transaction, description: 'Amazon Purchase', amount: 50, category: nil)
    t2 = create(:transaction, description: 'Expensive Item', amount: 1500, category: nil)

    post apply_categorization_rules_url

    assert_redirected_to categorization_rules_url

    t1.reload
    t2.reload
    assert_equal shopping_category.id, t1.category_id
    assert_equal high_value_category.id, t2.category_id  # Higher priority rule wins
  end

  test "should respect rule priority when applying" do
    shopping_category = create(:category, :shopping)
    online_category = create(:category, name: 'Online Shopping')
    
    # Lower priority rule
    rule1 = create(:categorization_rule,
      rule_type: :description_contains,
      pattern: 'purchase',
      category: shopping_category,
      priority: 5
    )
    
    # Higher priority rule
    rule2 = create(:categorization_rule,
      rule_type: :description_contains,
      pattern: 'amazon',
      category: online_category,
      priority: 10
    )

    transaction = create(:transaction, description: 'Amazon Purchase', category: nil)
    
    # Apply all rules
    CategorizationRule.apply_all_rules

    transaction.reload
    # Higher priority rule should win
    assert_equal online_category.id, transaction.category_id
  end

  # INDEX tests
  test "should get index" do
    create_list(:categorization_rule, 3)

    get categorization_rules_url
    assert_response :success
  end

  # NEW tests
  test "should get new" do
    get new_categorization_rule_url
    assert_response :success
  end

  # EDIT tests
  test "should get edit" do
    rule = create(:categorization_rule)

    get edit_categorization_rule_url(rule)
    assert_response :success
  end
end

