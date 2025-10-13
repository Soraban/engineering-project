require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  setup do
    Transaction.delete_all
    AnomalyFlag.delete_all
  end

  test "viewing dashboard shows statistics" do
    create_list(:transaction, 5)
    create_list(:transaction, 3, :flagged)
    create_list(:transaction, 2, category: nil)

    visit dashboard_url

    assert_text "Dashboard"
    assert_selector "h1, h2, h3", text: /Transactions|Statistics/i
  end

  test "reviewing flagged transactions" do
    flagged = create(:transaction, :flagged, description: "Suspicious Purchase")
    normal = create(:transaction, flagged: false, description: "Normal Purchase")

    visit review_dashboard_url

    # Should show flagged transactions
    assert_text "Suspicious Purchase"
    
    # Click to filter flagged only
    if has_link?("Flagged") || has_button?("Flagged")
      click_on "Flagged"
    end

    within "body" do
      assert_text "Suspicious Purchase"
    end
  end

  test "approving a single flagged transaction" do
    transaction = create(:transaction, :flagged, 
                        description: "Flagged Item",
                        status: :pending)
    flag = create(:anomaly_flag, transaction_record: transaction, resolved: false)

    visit review_dashboard_url

    # Find and click approve button for this transaction
    within "[data-transaction-id='#{transaction.id}'], tr", match: :first do
      click_on "Approve"
    end

    # Should be redirected back to review dashboard
    assert_current_path review_dashboard_url
    
    # Verify transaction was approved
    transaction.reload
    assert_equal 'reviewed', transaction.status
    assert_not transaction.flagged?
    
    flag.reload
    assert flag.resolved?
  end

  test "bulk approving multiple flagged transactions" do
    t1 = create(:transaction, :flagged, description: "Flagged 1")
    t2 = create(:transaction, :flagged, description: "Flagged 2")
    t3 = create(:transaction, :flagged, description: "Flagged 3")

    create(:anomaly_flag, transaction_record: t1)
    create(:anomaly_flag, transaction_record: t2)

    visit review_dashboard_url

    # Select multiple transactions
    check "transaction_ids_#{t1.id}"
    check "transaction_ids_#{t2.id}"
    check "transaction_ids_#{t3.id}"

    # Click bulk approve button
    click_on "Bulk Approve"

    # Should redirect back to review dashboard
    assert_current_path review_dashboard_url
    
    # Verify all transactions were approved
    [t1, t2, t3].each do |t|
      t.reload
      assert_equal 'reviewed', t.status
      assert_not t.flagged?
    end
  end

  test "filtering uncategorized transactions on review dashboard" do
    uncategorized = create(:transaction, category: nil, description: "Uncategorized Item")
    categorized = create(:transaction, :categorized, description: "Categorized Item")

    visit review_dashboard_url
    
    # Filter by uncategorized
    click_on "Uncategorized"

    # Should show uncategorized transaction
    assert_text "Uncategorized Item"
  end

  test "attempting bulk approve without selecting transactions shows error" do
    create(:transaction, :flagged)

    visit review_dashboard_url

    # Try to bulk approve without selecting anything
    click_on "Bulk Approve"

    # Should show an error message
    assert_text /select transactions/i
  end
end

