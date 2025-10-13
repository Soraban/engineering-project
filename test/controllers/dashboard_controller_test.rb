require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  # INDEX tests
  test "should get dashboard index" do
    get dashboard_url
    assert_response :success
  end

  test "should display statistics on dashboard" do
    create_list(:transaction, 5)
    create_list(:transaction, 3, :flagged)
    create_list(:transaction, 2, category: nil)

    get dashboard_url
    assert_response :success
  end

  # REVIEW tests
  test "should get review dashboard" do
    get review_dashboard_url
    assert_response :success
  end

  test "should show flagged transactions on review dashboard" do
    flagged = create(:transaction, :flagged)
    normal = create(:transaction, flagged: false)

    get review_dashboard_url, params: { filter: 'flagged' }
    assert_response :success
  end

  test "should show uncategorized transactions on review dashboard" do
    uncategorized = create(:transaction, category: nil)
    categorized = create(:transaction, :categorized)

    get review_dashboard_url, params: { filter: 'uncategorized' }
    assert_response :success
  end

  # APPROVE TRANSACTION tests
  test "should approve single transaction" do
    transaction = create(:transaction, :flagged, status: :pending)
    flag = create(:anomaly_flag, transaction_record: transaction, resolved: false)

    post approve_transaction_url(transaction)

    assert_redirected_to review_dashboard_url
    
    transaction.reload
    assert_equal 'reviewed', transaction.status
    assert_not transaction.flagged?
    
    flag.reload
    assert flag.resolved?
  end

  test "should mark transaction as reviewed and resolve anomalies" do
    transaction = create(:transaction, :flagged)
    flag1 = create(:anomaly_flag, transaction_record: transaction)
    flag2 = create(:anomaly_flag, transaction_record: transaction, anomaly_type: 'potential_duplicate')

    post approve_transaction_url(transaction)

    transaction.reload
    assert_equal 'reviewed', transaction.status
    assert_not transaction.flagged?
    
    assert flag1.reload.resolved?
    assert flag2.reload.resolved?
  end

  # BULK APPROVE tests
  test "should bulk approve multiple transactions" do
    t1 = create(:transaction, :flagged)
    t2 = create(:transaction, :flagged)
    t3 = create(:transaction, :flagged)

    flag1 = create(:anomaly_flag, transaction_record: t1)
    flag2 = create(:anomaly_flag, transaction_record: t2)

    post bulk_approve_url, params: {
      transaction_ids: "#{t1.id},#{t2.id},#{t3.id}"
    }

    assert_redirected_to review_dashboard_url

    [t1, t2, t3].each do |t|
      t.reload
      assert_equal 'reviewed', t.status
      assert_not t.flagged?
    end

    assert flag1.reload.resolved?
    assert flag2.reload.resolved?
  end

  test "should not bulk approve without transaction_ids" do
    post bulk_approve_url, params: {}

    assert_redirected_to review_dashboard_url
    assert_match /select transactions/, flash[:alert]
  end

  test "should handle bulk approve with mixed statuses" do
    pending = create(:transaction, status: :pending, flagged: true)
    already_approved = create(:transaction, status: :approved, flagged: true)

    post bulk_approve_url, params: {
      transaction_ids: "#{pending.id},#{already_approved.id}"
    }

    assert_redirected_to review_dashboard_url

    pending.reload
    already_approved.reload
    
    assert_equal 'reviewed', pending.status
    assert_equal 'reviewed', already_approved.status
  end
end

