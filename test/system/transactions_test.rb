require "application_system_test_case"

class TransactionsTest < ApplicationSystemTestCase
  setup do
    Transaction.delete_all
    AnomalyFlag.delete_all
    
    # Ensure categories exist
    @category = Category.find_or_create_by!(name: 'Shopping') do |c|
      c.description = 'Retail purchases'
      c.color = '#FF6B6B'
    end
    
    Category.find_or_create_by!(name: 'Food & Dining') do |c|
      c.description = 'Restaurants'
      c.color = '#4ECDC4'
    end
  end

  test "creating a new transaction" do
    visit transactions_url
    
    click_on "New Transaction"

    fill_in "Date", with: Date.today
    fill_in "Description", with: "Test Purchase"
    fill_in "Amount", with: "99.99"
    select "Shopping", from: "Category"

    click_on "Create Transaction"

    # Should redirect to transaction show page
    assert_text "Test Purchase"
    assert_text "99.99"
    
    # Verify transaction was created
    transaction = Transaction.last
    assert_equal "Test Purchase", transaction.description
    assert_equal 99.99, transaction.amount
    assert_equal "Shopping", transaction.category
  end

  test "creating transaction with missing required fields shows errors" do
    visit new_transaction_url

    fill_in "Description", with: "Invalid"
    # Don't fill in amount (required field)

    click_on "Create Transaction"

    # Should show validation errors
    assert_text /can't be blank|is required/i
  end

  test "editing an existing transaction" do
    transaction = create(:transaction, description: "Original", amount: 50.00)

    visit transactions_url
    
    # Find and click edit link
    within "[data-transaction-id='#{transaction.id}'], tr", match: :first do
      click_on "Edit"
    end

    fill_in "Description", with: "Updated Description"
    fill_in "Amount", with: "150.00"

    click_on "Update Transaction"

    # Should show updated values
    assert_text "Updated Description"
    assert_text "150.00"
    
    transaction.reload
    assert_equal "Updated Description", transaction.description
    assert_equal 150.00, transaction.amount
  end

  test "deleting a transaction" do
    transaction = create(:transaction, description: "To Delete")

    visit transactions_url

    # Should show the transaction
    assert_text "To Delete"

    # Find and click delete button
    within "[data-transaction-id='#{transaction.id}'], tr", match: :first do
      accept_confirm do
        click_on "Delete"
      end
    end

    # Should redirect to transactions list
    assert_current_path transactions_url
    
    # Transaction should be deleted
    assert_not Transaction.exists?(transaction.id)
  end

  test "bulk categorizing multiple transactions" do
    t1 = create(:transaction, category: nil, description: "Item 1")
    t2 = create(:transaction, category: nil, description: "Item 2")
    t3 = create(:transaction, category: nil, description: "Item 3")

    visit transactions_url

    # Select multiple transactions
    check "transaction_ids_#{t1.id}"
    check "transaction_ids_#{t2.id}"
    check "transaction_ids_#{t3.id}"

    # Select category from bulk actions
    select "Shopping", from: "category"
    
    # Click bulk categorize button
    click_on "Bulk Categorize"

    # Should redirect back to transactions list
    assert_current_path transactions_url
    
    # Verify all transactions were categorized
    [t1, t2, t3].each do |t|
      t.reload
      assert_equal "Shopping", t.category
    end
  end

  test "filtering transactions by category" do
    shopping = create(:transaction, category: "Shopping", description: "Shopping Item")
    food = create(:transaction, category: "Food & Dining", description: "Food Item")

    visit transactions_url

    # Filter by Shopping category
    select "Shopping", from: "category_filter"
    click_on "Filter"

    # Should show only shopping transactions
    assert_text "Shopping Item"
  end

  test "filtering flagged transactions" do
    flagged = create(:transaction, :flagged, description: "Flagged Item")
    normal = create(:transaction, flagged: false, description: "Normal Item")

    visit transactions_url

    # Filter by flagged
    check "flagged"
    click_on "Filter"

    # Should show only flagged transactions
    assert_text "Flagged Item"
  end

  test "importing transactions from CSV" do
    visit transactions_url
    
    click_on "Import CSV"

    # Create a temporary CSV file
    csv_content = <<~CSV
      date,description,amount,category
      #{Date.today},Amazon Purchase,299.99,Shopping
      #{Date.today},Grocery Store,67.50,Food & Dining
    CSV

    # Attach the file
    attach_file "file", StringIO.new(csv_content), make_visible: true

    click_on "Import"

    # Should show success message
    assert_text /Import completed/i
    
    # Should redirect to transactions list
    assert_current_path transactions_url
    
    # Verify transactions were imported
    assert Transaction.exists?(description: "Amazon Purchase")
    assert Transaction.exists?(description: "Grocery Store")
  end

  test "importing CSV with no file shows error" do
    visit import_transactions_url

    click_on "Import"

    # Should show error message
    assert_text /Please select.*CSV file/i
  end

  test "viewing transaction details" do
    transaction = create(:transaction, 
                        description: "Detailed Purchase",
                        amount: 123.45,
                        category: "Shopping",
                        date: Date.today)

    visit transactions_url
    
    # Click on transaction to view details
    click_on "Detailed Purchase"

    # Should show all transaction details
    assert_text "Detailed Purchase"
    assert_text "123.45"
    assert_text "Shopping"
  end
end

