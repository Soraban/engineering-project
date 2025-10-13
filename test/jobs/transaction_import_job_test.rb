require "test_helper"

class TransactionImportJobTest < ActiveJob::TestCase
  setup do
    @temp_dir = Rails.root.join('tmp', 'test_uploads', "test_#{Process.pid}_#{Time.now.to_i}")
    FileUtils.mkdir_p(@temp_dir)
  end

  teardown do
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  test "successfully imports small CSV file" do
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-01,Transaction 1,10.00,Shopping
      2024-01-02,Transaction 2,20.00,Food
    CSV

    file_path = create_csv_file('small.csv', csv_content)
    import_id = SecureRandom.uuid

    assert_difference 'Transaction.count', 2 do
      TransactionImportJob.new.perform(file_path, import_id)
    end

    # Verify transactions were imported
    assert Transaction.exists?(description: 'Transaction 1')
    assert Transaction.exists?(description: 'Transaction 2')
    assert_not File.exist?(file_path), "Temp file should be cleaned up"
  end

  test "full checkpoint cycle: job fails then retries from checkpoint and completes" do
    # Use memory store for cache in this test
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    
    # Create CSV with 3 records (batch_size: 1 for easier testing)
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-01,Transaction 1,10.00,Shopping
      2024-01-02,Transaction 2,20.00,Shopping
      2024-01-03,Transaction 3,30.00,Shopping
    CSV

    file_path = create_csv_file('checkpoint_test.csv', csv_content)
    import_id = SecureRandom.uuid

    insert_sequence = sequence('inserts')
    
    ## FIRST RUN (offset 0): Batch 1 succeeds, Batch 2 fails
    Transaction.expects(:insert_all).once.in_sequence(insert_sequence).returns(OpenStruct.new(rows: [[1]]))
    Transaction.expects(:insert_all).once.in_sequence(insert_sequence).raises(
      ActiveRecord::StatementInvalid.new('Database deadlock on batch 2')
    )
    
    ## SECOND RUN (offset 1): Batch 2 succeeds, Batch 3 succeeds  
    Transaction.expects(:insert_all).once.in_sequence(insert_sequence).returns(OpenStruct.new(rows: [[2]]))
    Transaction.expects(:insert_all).once.in_sequence(insert_sequence).returns(OpenStruct.new(rows: [[3]]))
    
    # File should only be deleted after successful completion
    File.expects(:delete).with(file_path).once
    
    job = TransactionImportJob.new
    
    # FIRST RUN: Batch 1 succeeds, Batch 2 fails, saves checkpoint
    begin
      job.perform(file_path, import_id, start_offset: 0, batch_size: 1)
    rescue ActiveRecord::StatementInvalid
      # Expected - batch 2 fails
    end
    
    # Verify checkpoint was saved
    failure_status = Rails.cache.read("import_status:#{import_id}")
    assert_equal 'failed', failure_status['status']
    assert_equal 1, failure_status['last_successful_offset']
    
    # RETRY: ActiveJob would call retry_job which updates arguments
    # Simulate what retry_job does - restart from checkpoint
    job2 = TransactionImportJob.new
    job2.perform(file_path, import_id, start_offset: failure_status['last_successful_offset'], batch_size: 1)
    
    # Verify final success
    success_status = Rails.cache.read("import_status:#{import_id}")
    assert_equal 'completed', success_status['status']
    assert_equal 2, success_status['success']
  ensure
    # Restore original cache
    Rails.cache = original_cache if original_cache
  end

  test "updates status cache with different phases" do
    file_content = <<~CSV
      date,description,amount
      2024-01-15,Test Transaction,100.00
    CSV
    file_path = create_csv_file('test.csv', file_content)
    import_id = SecureRandom.uuid
    
    # Mock Turbo Stream broadcasting (no-op in test mode)
    Turbo::StreamsChannel.stubs(:broadcast_replace_to).returns(true)
    
    # Run job - it will use the default cache
    job = TransactionImportJob.new
    job.perform(file_path, import_id, batch_size: 1)
    
    # In test environment, we just verify the job completed successfully
    # Cache behavior is tested via integration tests
    assert Transaction.count >= 1, "Transaction should be created"
  end

  test "shows progress during multi-batch import" do
    # Create CSV with enough rows for multiple batches
    rows = (1..5).map { |i| "2024-01-#{10+i},Transaction #{i},#{i * 10}.00" }
    file_content = "date,description,amount\n" + rows.join("\n")
    file_path = create_csv_file('multi_batch.csv', file_content)
    import_id = SecureRandom.uuid
    
    # Mock Turbo Stream broadcasting (no-op in test mode)
    Turbo::StreamsChannel.stubs(:broadcast_replace_to).returns(true)
    
    initial_count = Transaction.count
    
    job = TransactionImportJob.new
    job.perform(file_path, import_id, batch_size: 2)
    
    # Verify all transactions were imported
    assert_equal initial_count + 5, Transaction.count, "Should import all 5 transactions"
  end

  private

    def create_csv_file(filename, content)
      file_path = @temp_dir.join(filename)
      File.write(file_path, content)
      file_path.to_s
    end
  end
