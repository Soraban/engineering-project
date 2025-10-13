require "test_helper"

class TransactionCreationServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # SINGLE TRANSACTION CREATION TESTS

  test "creates a single transaction successfully" do
    service = TransactionCreationService.new
    
    transaction = service.create_single(
      date: Date.today,
      description: "Test Purchase",
      amount: 100.00,
      category: "Shopping"
    )

    assert_not_nil transaction
    assert transaction.persisted?
    assert_equal 1, service.results[:success]
    assert_includes service.results[:imported_ids], transaction.id
  end

  test "applies categorization rule when creating single uncategorized transaction" do
    shopping_category = create(:category, :shopping)
    create(:categorization_rule,
           rule_type: :description_contains,
           pattern: 'amazon',
           category: shopping_category,
           priority: 10)

    service = TransactionCreationService.new
    transaction = service.create_single(
      date: Date.today,
      description: "Amazon Purchase",
      amount: 100.00,
      category: nil  # No category provided
    )

    assert_not_nil transaction
    assert_equal 'Shopping', transaction.category.name,
                 "Should auto-categorize using matching rule"
  end

  test "enqueues anomaly detection job for single transaction" do
    service = TransactionCreationService.new
    
    assert_enqueued_jobs 1, only: AnomalyDetectionJob do
      service.create_single(
        date: Date.today,
        description: "Test",
        amount: 100.00
      )
    end
  end

  test "detects duplicates during single transaction creation" do
    shopping_category = create(:category, :shopping)
    # Create existing transaction
    Transaction.create!(
      date: Date.today,
      description: "Duplicate Test",
      amount: 100.00,
      category: shopping_category
    )

    service = TransactionCreationService.new
    
    # Create duplicate transaction
    duplicate = service.create_single(
      date: Date.today,
      description: "Duplicate Test",
      amount: 100.00,
      category: nil
    )

    assert_not_nil duplicate, "Transaction should be created"
    
    # Process anomaly detection
    perform_enqueued_jobs
    
    duplicate.reload
    assert duplicate.flagged?, "Duplicate should be flagged"
    assert duplicate.anomaly_flags.potential_duplicate.any?,
           "Should have potential duplicate flag"
  end

  test "returns nil and records error when single transaction is invalid" do
    service = TransactionCreationService.new
    
    transaction = service.create_single(
      date: nil,  # Invalid - required field
      description: "Test",
      amount: 100.00
    )

    assert_nil transaction
    assert_equal 0, service.results[:success]
    assert_equal 1, service.results[:errors].count
  end

  # BULK TRANSACTION CREATION TESTS

  test "bulk creates multiple transactions successfully" do
    service = TransactionCreationService.new
    
    transactions_data = [
      { date: Date.today, description: "Transaction 1", amount: 100.00, category: nil },
      { date: Date.today, description: "Transaction 2", amount: 200.00, category: "Shopping" },
      { date: Date.today, description: "Transaction 3", amount: 300.00, category: nil }
    ]

    ids = service.create_bulk(transactions_data)

    assert_equal 3, ids.count
    assert_equal 3, service.results[:success]
    assert_equal 3, Transaction.count
    assert_equal ids, service.results[:imported_ids]
  end

  test "applies categorization rules during bulk import" do
    shopping_category = create(:category, :shopping)
    create(:categorization_rule,
           rule_type: :description_contains,
           pattern: 'amazon',
           category: shopping_category,
           priority: 10)

    service = TransactionCreationService.new
    
    transactions_data = [
      { date: Date.today, description: "Amazon Purchase", amount: 100.00, category: nil },
      { date: Date.today, description: "Random Store", amount: 50.00, category: nil }
    ]

    service.create_bulk(transactions_data)

    # Check categories were applied correctly during insert
    amazon_transaction = Transaction.find_by(description: "Amazon Purchase")
    random_transaction = Transaction.find_by(description: "Random Store")

    assert_equal 'Shopping', amazon_transaction.category.name,
                 "Amazon transaction should be auto-categorized"
    assert_nil random_transaction.category_id,
               "Random transaction should remain uncategorized"
  end

  test "applies highest priority rule when multiple rules match during bulk import" do
    general_category = create(:category, name: 'General')
    online_shopping_category = create(:category, name: 'Online Shopping')
    
    create(:categorization_rule,
           rule_type: :description_contains,
           pattern: 'purchase',
           category: general_category,
           priority: 5)
    
    create(:categorization_rule,
           rule_type: :description_contains,
           pattern: 'amazon',
           category: online_shopping_category,
           priority: 10)

    service = TransactionCreationService.new
    
    transactions_data = [
      { date: Date.today, description: "Amazon Purchase", amount: 100.00, category: nil }
    ]

    service.create_bulk(transactions_data)

    transaction = Transaction.last
    assert_equal 'Online Shopping', transaction.category.name,
                 "Should apply highest priority matching rule"
  end

  test "bulk import creates transactions without anomaly detection" do
    service = TransactionCreationService.new
    
    transactions_data = [
      { date: Date.today, description: "Transaction 1", amount: 100.00, category: nil },
      { date: Date.today, description: "Transaction 2", amount: 200.00, category: nil },
      { date: Date.today, description: "Transaction 3", amount: 300.00, category: nil }
    ]

    # Service should NOT enqueue jobs - that's the job's responsibility
    assert_no_enqueued_jobs only: BatchAnomalyDetectionJob do
      inserted_ids = service.create_bulk(transactions_data)
      assert_equal 3, inserted_ids.count
    end
  end

  test "bulk import returns inserted transaction IDs" do
    service = TransactionCreationService.new
    
    transactions_data = [
      { date: Date.today, description: "Transaction 1", amount: 100.00, category: nil },
      { date: Date.today, description: "Transaction 2", amount: 200.00, category: nil }
    ]

    inserted_ids = service.create_bulk(transactions_data)
    
    assert_equal 2, inserted_ids.count
    assert_equal 2, service.results[:success]
    assert_equal inserted_ids, service.results[:imported_ids]
  end

  test "normalizes descriptions during bulk insert" do
    service = TransactionCreationService.new
    
    transactions_data = [
      { date: Date.today, description: "  Extra   Spaces  ", amount: 100.00, category: nil }
    ]

    service.create_bulk(transactions_data)

    transaction = Transaction.last
    assert_equal "Extra Spaces", transaction.description,
                 "Description should be normalized"
  end

  test "generates description hash during bulk insert" do
    service = TransactionCreationService.new
    
    transactions_data = [
      { date: Date.today, description: "Test Transaction", amount: 100.00, category: nil }
    ]

    service.create_bulk(transactions_data)

    transaction = Transaction.last
    assert_not_nil transaction.description_hash,
                   "Description hash should be generated"
    assert_equal 64, transaction.description_hash.length,
                 "SHA-256 hash should be 64 characters"
  end

  test "handles empty bulk data gracefully" do
    service = TransactionCreationService.new
    
    ids = service.create_bulk([])

    assert_equal [], ids
    assert_equal 0, service.results[:success]
  end

  test "excludes invalid transactions during bulk insert" do
    service = TransactionCreationService.new
    
    transactions_data = [
      { date: Date.today, description: "Valid", amount: 100.00, category: nil },
      { date: nil, description: "Invalid - missing date", amount: 200.00, category: nil },
      { date: Date.today, description: "Valid 2", amount: 300.00, category: nil },
      { date: Date.today, description: "Invalid - missing amount", amount: nil, category: nil },
      { date: Date.today, description: "Valid 3", amount: 400.00, category: nil }
    ]

    ids = service.create_bulk(transactions_data)

    # Only 3 valid transactions should be inserted
    assert_equal 3, ids.count
    assert_equal 3, service.results[:success]
    assert_equal 3, Transaction.count
    
    # Should record 2 errors
    assert_equal 2, service.results[:errors].count
    assert service.results[:errors].any? { |e| e.include?("Missing date") }
    assert service.results[:errors].any? { |e| e.include?("Missing amount") }
  end

  test "filters all invalid data and inserts none when all are invalid" do
    service = TransactionCreationService.new
    
    transactions_data = [
      { date: nil, description: "Invalid 1", amount: 100.00, category: nil },
      { date: Date.today, description: "Invalid 2", amount: nil, category: nil }
    ]

    ids = service.create_bulk(transactions_data)

    # No transactions should be inserted
    assert_equal [], ids
    assert_equal 0, service.results[:success]
    assert_equal 0, Transaction.count
    assert_equal 2, service.results[:errors].count
  end

  # CLASS METHOD TESTS

  test "class method create_single returns transaction and results" do
    transaction, results = TransactionCreationService.create_single(
      date: Date.today,
      description: "Test",
      amount: 100.00
    )

    assert_not_nil transaction
    assert_equal 1, results[:success]
  end

  test "class method create_bulk returns ids and results" do
    transactions_data = [
      { date: Date.today, description: "Test 1", amount: 100.00, category: nil },
      { date: Date.today, description: "Test 2", amount: 200.00, category: nil }
    ]

    ids, results = TransactionCreationService.create_bulk(transactions_data)

    assert_equal 2, ids.count
    assert_equal 2, results[:success]
  end

  # PERFORMANCE AND CACHING TESTS

  test "caches categorization rules to avoid N+1 queries" do
    test_category = create(:category, name: 'Test')
    create(:categorization_rule,
           rule_type: :description_contains,
           pattern: 'test',
           category: test_category,
           priority: 10)

    service = TransactionCreationService.new
    
    # Rules should be cached on initialization
    assert_not_nil service.instance_variable_get(:@categorization_rules)
    assert_equal 1, service.instance_variable_get(:@categorization_rules).count
  end

  test "applies category during bulk insert" do
    shopping_category = create(:category, :shopping)
    create(:categorization_rule,
           rule_type: :description_contains,
           pattern: 'amazon',
           category: shopping_category,
           priority: 10)

    service = TransactionCreationService.new
    
    transactions_data = [
      { date: Date.today, description: "Amazon Purchase", amount: 100.00, category: nil }
    ]

    service.create_bulk(transactions_data)
    
    # Category should be set during insert (no additional update needed)
    transaction = Transaction.last
    assert_equal 'Shopping', transaction.category.name,
                 "Category should be applied during insert"
    # Verify only 1 update happened (the insert itself, not insert + update)
    assert_equal transaction.created_at.to_i, transaction.updated_at.to_i,
                 "Should not have been updated after creation"
  end
end

