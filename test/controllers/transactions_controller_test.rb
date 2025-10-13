require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest

  test "should create transaction with valid attributes" do
    shopping_category = create(:category, :shopping)
    
    assert_difference('Transaction.count', 1) do
      post transactions_url, params: {
        transaction: {
          date: Date.today,
          description: 'Test Purchase',
          amount: 99.99,
          category_id: shopping_category.id
        }
      }
    end

    assert_redirected_to transaction_path(Transaction.last)
    
    transaction = Transaction.last
    assert_equal Date.today, transaction.date
    assert_equal 'Test Purchase', transaction.description  # normalized (light - preserves case)
    assert_equal 99.99, transaction.amount
    assert_equal shopping_category.id, transaction.category_id
    assert_not_nil transaction.description_hash  # Hash generated
  end

  test "should not create transaction with missing required fields" do
    assert_no_difference('Transaction.count') do
      post transactions_url, params: {
        transaction: {
          description: 'Invalid',
          amount: nil
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should normalize description on create" do
    post transactions_url, params: {
      transaction: {
        date: Date.today,
        description: '  Amazon   Purchase!!!  ',
        amount: 50.00
      }
    }

    transaction = Transaction.last
    # Light normalization preserves case and special chars
    assert_equal 'Amazon Purchase!!!', transaction.description
    # But hash is generated from aggressive normalization
    assert_not_nil transaction.description_hash
  end

  # UPDATE tests
  test "should update transaction" do
    shopping_category = create(:category, :shopping)
    transaction = create(:transaction)

    patch transaction_url(transaction), params: {
      transaction: {
        description: 'Updated Description',
        amount: 150.00,
        category_id: shopping_category.id
      }
    }

    assert_redirected_to transaction_path(transaction)
    
    transaction.reload
    assert_equal 'Updated Description', transaction.description  # Preserves case
    assert_equal 150.00, transaction.amount
    assert_equal shopping_category.id, transaction.category_id
    assert_not_nil transaction.description_hash  # Hash regenerated
  end

  test "should not update transaction with invalid data" do
    transaction = create(:transaction, amount: 100.00)

    patch transaction_url(transaction), params: {
      transaction: {
        amount: nil
      }
    }

    assert_response :unprocessable_entity
    transaction.reload
    assert_equal 100.00, transaction.amount  # unchanged
  end

  # DELETE tests
  test "should destroy transaction" do
    transaction = create(:transaction)

    assert_difference('Transaction.count', -1) do
      delete transaction_url(transaction)
    end

    assert_redirected_to transactions_url
  end

  test "should destroy transaction and associated anomaly flags" do
    transaction = create(:transaction, :with_anomalies)
    anomaly_flag = transaction.anomaly_flags.first

    assert_difference('Transaction.count', -1) do
      assert_difference('AnomalyFlag.count', -1) do
        delete transaction_url(transaction)
      end
    end
  end

  # BULK CATEGORIZE tests
  test "should bulk categorize multiple transactions" do
    category = create(:category, :shopping)
    t1 = create(:transaction, category: nil)
    t2 = create(:transaction, category: nil)
    t3 = create(:transaction, category: nil)

    post bulk_categorize_transactions_url, params: {
      transaction_ids: "#{t1.id},#{t2.id},#{t3.id}",
      category_id: category.id
    }

    assert_redirected_to transactions_url

    [t1, t2, t3].each do |t|
      t.reload
      assert_equal category.id, t.category_id
    end
  end

  test "should not bulk categorize without transaction_ids" do
    shopping_category = create(:category, :shopping)
    post bulk_categorize_transactions_url, params: {
      category_id: shopping_category.id
    }

    assert_redirected_to transactions_url
    assert_match /select transactions/, flash[:alert]
  end

  test "should not bulk categorize without category" do
    transaction = create(:transaction)

    post bulk_categorize_transactions_url, params: {
      transaction_ids: transaction.id.to_s
    }

    assert_redirected_to transactions_url
    assert_match /select.*category/, flash[:alert]
  end

  # IMPORT tests
  test "should import transactions from CSV" do
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,Amazon Purchase,299.99,Shopping
      2024-01-16,Grocery Store,67.50,Food & Dining
    CSV

    # Create temp file
    temp_file = Tempfile.new(['test', '.csv'])
    temp_file.write(csv_content)
    temp_file.rewind

    file = Rack::Test::UploadedFile.new(
      temp_file.path,
      'text/csv',
      original_filename: 'test.csv'
    )

    # Execute the job inline when it's enqueued
    assert_difference('Transaction.count', 2) do
      perform_enqueued_jobs do
        post import_transactions_url, params: { file: file }
      end
    end

    # Now async, redirects to status page (no flash message)
    assert_response :redirect
    assert_match /import_status/, response.location
    
    temp_file.close
    temp_file.unlink
  end

  test "should import duplicates and let anomaly detection flag them" do
    # Create existing transaction
    create(:transaction, 
      date: Date.parse('2024-01-15'),
      description: 'Amazon Purchase',
      amount: 299.99
    )

    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,Amazon Purchase,299.99,Shopping
      2024-01-16,New Transaction,50.00,
    CSV

    temp_file = Tempfile.new(['duplicates', '.csv'])
    temp_file.write(csv_content)
    temp_file.rewind

    file = Rack::Test::UploadedFile.new(
      temp_file.path,
      'text/csv',
      original_filename: 'duplicates.csv'
    )

    # Both transactions should be imported (duplicate detection via anomaly detection)
    assert_difference('Transaction.count', 2) do
      perform_enqueued_jobs do
        post import_transactions_url, params: { file: file }
      end
    end

    # Now processing async, so we get redirected to status page (no flash message)
    assert_response :redirect
    assert_match /import_status/, response.location
    
    temp_file.close
    temp_file.unlink
  end

  test "should handle CSV import with errors" do
    csv_content = <<~CSV
      date,description,amount,category
      ,Invalid Transaction,,
      2024-01-16,Valid Transaction,50.00,
    CSV

    temp_file = Tempfile.new(['errors', '.csv'])
    temp_file.write(csv_content)
    temp_file.rewind

    file = Rack::Test::UploadedFile.new(
      temp_file.path,
      'text/csv',
      original_filename: 'errors.csv'
    )

    # Valid transaction imported, invalid one skipped
    assert_difference('Transaction.count', 1) do
      perform_enqueued_jobs do
        post import_transactions_url, params: { file: file }
      end
    end
    
    assert Transaction.exists?(description: 'Valid Transaction')
    
    temp_file.close
    temp_file.unlink
  end

  test "should reject import without file" do
    post import_transactions_url, params: {}

    assert_response :success  # Re-renders import form
    assert_match /Please select a CSV file/, flash[:alert]
  end

  # INDEX tests
  test "should get index" do
    create_list(:transaction, 3)

    get transactions_url
    assert_response :success
  end

  test "should filter by category" do
    shopping_category = create(:category, :shopping)
    food_category = create(:category, :food)
    create(:transaction, category: shopping_category)
    create(:transaction, category: food_category)

    get transactions_url, params: { category: shopping_category.id }
    assert_response :success
  end

  test "should filter by flagged" do
    create(:transaction, :flagged)
    create(:transaction, flagged: false)

    get transactions_url, params: { flagged: 'true' }
    assert_response :success
  end

  # SHOW tests
  test "should show transaction" do
    transaction = create(:transaction)

    get transaction_url(transaction)
    assert_response :success
  end

  # NEW tests
  test "should get new" do
    get new_transaction_url
    assert_response :success
  end

  # EDIT tests
  test "should get edit" do
    transaction = create(:transaction)

    get edit_transaction_url(transaction)
    assert_response :success
  end

  # IMPORT STATUS tests
  def setup_cache_store
    # Use memory store for tests that need caching
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end
  
  def teardown_cache_store
    Rails.cache = @original_cache if @original_cache
  end

  test "should show import status page with queued status" do
    setup_cache_store
    import_id = SecureRandom.uuid
    Rails.cache.write("import_status:#{import_id}", {
      'status' => 'queued',
      'started_at' => Time.current.to_s
    }, expires_in: 1.hour)

    get import_status_transactions_path(import_id)
    assert_response :success
    assert_select 'h2', text: 'Import Queued'
    teardown_cache_store
  end

  test "should show import status page with processing status" do
    setup_cache_store
    import_id = SecureRandom.uuid
    Rails.cache.write("import_status:#{import_id}", {
      'status' => 'processing',
      'phase' => 'importing',
      'processed' => 50,
      'started_at' => Time.current.to_s
    }, expires_in: 1.hour)

    get import_status_transactions_path(import_id)
    assert_response :success
    assert_select 'h2', text: 'Importing Transactions'
    assert_select '.big-number', text: '50'
    teardown_cache_store
  end

  test "should show import status page with anomaly detection phase" do
    setup_cache_store
    import_id = SecureRandom.uuid
    Rails.cache.write("import_status:#{import_id}", {
      'status' => 'processing',
      'phase' => 'anomaly_detection',
      'success' => 100,
      'started_at' => Time.current.to_s
    }, expires_in: 1.hour)

    get import_status_transactions_path(import_id)
    assert_response :success
    assert_select 'h2', text: 'Import Complete!'
    assert_select '.progress-label-large', text: 'Running Anomaly Detection'
    teardown_cache_store
  end

  test "should show import status page with completed status" do
    setup_cache_store
    import_id = SecureRandom.uuid
    Rails.cache.write("import_status:#{import_id}", {
      'status' => 'completed',
      'phase' => 'anomaly_detection_running',
      'success' => 100,
      'errors' => [],
      'completed_at' => Time.current.to_s
    }, expires_in: 1.hour)

    get import_status_transactions_path(import_id)
    assert_response :success
    assert_select 'h2.success-title', text: 'Import Complete!'
    assert_select '.stat-number', text: '100'
    teardown_cache_store
  end

  test "should show import status page with errors" do
    setup_cache_store
    import_id = SecureRandom.uuid
    Rails.cache.write("import_status:#{import_id}", {
      'status' => 'completed',
      'success' => 50,
      'errors' => ['Error 1', 'Error 2'],
      'completed_at' => Time.current.to_s
    }, expires_in: 1.hour)

    get import_status_transactions_path(import_id)
    assert_response :success
    assert_select '.stat-warning .stat-number', text: '2'
    assert_select '.error-reason', text: 'Error 1'
    teardown_cache_store
  end

  test "should return JSON status for API polling fallback" do
    setup_cache_store
    import_id = SecureRandom.uuid
    Rails.cache.write("import_status:#{import_id}", {
      'status' => 'processing',
      'phase' => 'importing',
      'processed' => 75
    }, expires_in: 1.hour)

    get import_status_transactions_path(import_id, format: :json)
    assert_response :success
    
    json = JSON.parse(response.body)
    assert_equal 'processing', json['status']
    assert_equal 'importing', json['phase']
    assert_equal 75, json['processed']
    teardown_cache_store
  end

  test "should redirect if import status not found" do
    setup_cache_store
    get import_status_transactions_path('nonexistent-id')
    assert_response :redirect
    assert_redirected_to transactions_path
    assert_match /not found or expired/, flash[:alert]
    teardown_cache_store
  end
end

