require "test_helper"

class BatchAnomalyDetectionJobTest < ActiveJob::TestCase
  test "processes anomaly detection for multiple transactions" do
    shopping_category = create(:category, :shopping)
    t1 = create(:transaction, description: "no description", category: nil)
    t2 = create(:transaction, description: "no description", category: nil)
    t3 = create(:transaction, amount: 100.00, category: shopping_category)

    BatchAnomalyDetectionJob.perform_now([t1.id, t2.id, t3.id])

    # First two should be flagged for missing metadata
    t1.reload
    t2.reload
    t3.reload

    assert t1.flagged?, "Transaction 1 should be flagged"
    assert t1.anomaly_flags.missing_metadata.any?
    
    assert t2.flagged?, "Transaction 2 should be flagged"
    assert t2.anomaly_flags.missing_metadata.any?
    
    # Third one has no issues
    assert_not t3.flagged?
  end

  test "handles empty transaction ids array" do
    assert_nothing_raised do
      BatchAnomalyDetectionJob.perform_now([])
    end
  end

  test "handles nil transaction ids" do
    assert_nothing_raised do
      BatchAnomalyDetectionJob.perform_now(nil)
    end
  end

  test "skips non-existent transactions gracefully" do
    valid_transaction = create(:transaction, description: "no description", category: nil)
    non_existent_id = 999999

    assert_nothing_raised do
      BatchAnomalyDetectionJob.perform_now([valid_transaction.id, non_existent_id])
    end

    # Valid transaction should still be processed
    valid_transaction.reload
    assert valid_transaction.flagged?
  end

  test "detects duplicates in batch" do
    shopping_category = create(:category, :shopping)
    test_date = Date.today
    test_amount = 150.00
    test_description = "Duplicate Transaction"

    existing = create(:transaction,
                     date: test_date,
                     amount: test_amount,
                     description: test_description,
                     category: shopping_category)
    
    duplicate = create(:transaction,
                      date: test_date,
                      amount: test_amount,
                      description: test_description,
                      category: nil)

    BatchAnomalyDetectionJob.perform_now([duplicate.id])

    duplicate.reload
    assert duplicate.flagged?
    assert duplicate.anomaly_flags.potential_duplicate.any?
  end

  test "processes large batch efficiently" do
    # Create 100 transactions with missing metadata
    transaction_ids = 100.times.map do
      create(:transaction, description: "no description", category: nil).id
    end

    start_time = Time.current
    BatchAnomalyDetectionJob.perform_now(transaction_ids)
    duration = Time.current - start_time

    # Should process 100 transactions reasonably fast (< 5 seconds in test env)
    assert duration < 5, "Batch job should process 100 transactions in under 5 seconds"
    
    # All should be flagged
    flagged_count = Transaction.where(id: transaction_ids, flagged: true).count
    assert_equal 100, flagged_count, "All transactions should be flagged"
  end

  test "processes all transactions in batch" do
    shopping_category = create(:category, :shopping)
    t1 = create(:transaction, description: "no description", category: nil)
    t2 = create(:transaction, description: "no description", category: nil)
    t3 = create(:transaction, amount: 100.00, category: shopping_category)

    # Process all at once
    BatchAnomalyDetectionJob.perform_now([t1.id, t2.id, t3.id])

    # All transactions should be processed
    assert Transaction.find(t1.id).anomaly_flags.any?
    assert Transaction.find(t2.id).anomaly_flags.any?
    assert_not_nil Transaction.find(t3.id)
  end
end

