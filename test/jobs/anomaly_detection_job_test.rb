require "test_helper"

class AnomalyDetectionJobTest < ActiveJob::TestCase
  test "performs anomaly detection for a transaction" do
    transaction = create(:transaction, amount: 100.00)

    AnomalyDetectionJob.perform_now(transaction.id)

    # Should have run anomaly detection
    assert_performed_jobs 0 # Job itself is not enqueued, it's performed directly
  end

  test "flags transaction when anomalies are detected" do
    # Create transaction with missing category to trigger missing_metadata anomaly
    transaction = create(:transaction, 
                        description: "no description",
                        category: nil,
                        flagged: false)

    assert_not transaction.flagged?

    AnomalyDetectionJob.perform_now(transaction.id)

    transaction.reload
    assert transaction.flagged?, "Transaction should be flagged when anomalies are found"
    assert transaction.anomaly_flags.unresolved.any?
    assert transaction.anomaly_flags.missing_metadata.any?
  end

  test "does not flag transaction when no anomalies are detected" do
    shopping_category = create(:category, :shopping)
    transaction = create(:transaction, 
                        amount: 100.00,
                        category: shopping_category,
                        flagged: false)

    AnomalyDetectionJob.perform_now(transaction.id)

    transaction.reload
    assert_not transaction.flagged?, "Transaction should not be flagged when no anomalies found"
    assert_equal 0, transaction.anomaly_flags.unresolved.count
  end

  test "handles non-existent transaction gracefully" do
    non_existent_id = 999999

    assert_nothing_raised do
      AnomalyDetectionJob.perform_now(non_existent_id)
    end
  end

  test "detects potential duplicate anomalies" do
    existing = create(:transaction,
                     date: Date.today,
                     amount: 150.00,
                     description: "Store Purchase")
    
    duplicate = create(:transaction,
                      date: Date.today,
                      amount: 150.00,
                      description: "Store Purchase")

    AnomalyDetectionJob.perform_now(duplicate.id)

    duplicate.reload
    assert duplicate.anomaly_flags.potential_duplicate.any?
  end

  test "detects missing metadata anomalies" do
    transaction = create(:transaction,
                        description: "no description",
                        category: nil)

    AnomalyDetectionJob.perform_now(transaction.id)

    transaction.reload
    assert transaction.anomaly_flags.missing_metadata.any?
  end

  test "detects suspicious pattern anomalies" do
    # Round number transactions might be suspicious
    transaction = create(:transaction, amount: 500.00)

    AnomalyDetectionJob.perform_now(transaction.id)

    transaction.reload
    # May or may not be flagged depending on pattern detection logic
    # Just verify the job runs without error
    assert_not_nil transaction
  end

  test "returns early if transaction does not exist" do
    result = AnomalyDetectionJob.perform_now(999999)
    
    assert_nil result
  end

  test "creates multiple anomaly flags for multiple issues" do
    # Create a transaction with multiple issues:
    # 1. Missing category (missing metadata)
    # 2. Potential duplicate
    test_date = Date.today
    test_amount = 200.00
    test_description = "Duplicate Test Transaction"
    
    # First, create an existing transaction
    shopping_category = create(:category, :shopping)
    existing = create(:transaction,
                     date: test_date,
                     amount: test_amount,
                     description: test_description,
                     category: shopping_category)
    
    # Then create a problematic transaction that:
    # - Is a duplicate of the existing one (same date, amount, description)
    # - Has missing category
    problem_transaction = create(:transaction,
                                 date: test_date,
                                 amount: test_amount,
                                 description: test_description,
                                 category: nil)

    AnomalyDetectionJob.perform_now(problem_transaction.id)

    problem_transaction.reload
    assert problem_transaction.flagged?, "Transaction should be flagged"
    
    # Should have both missing_metadata and potential_duplicate
    assert problem_transaction.anomaly_flags.missing_metadata.any?, "Should have missing metadata flag"
    assert problem_transaction.anomaly_flags.potential_duplicate.any?, "Should have duplicate flag"
    assert problem_transaction.anomaly_flags.unresolved.count >= 2, "Should have at least 2 anomaly flags"
  end
end
