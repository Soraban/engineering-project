require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    transaction = build(:transaction)
    assert transaction.valid?
  end
  
  test "should require date" do
    transaction = build(:transaction, date: nil)
    assert_not transaction.valid?
    assert_includes transaction.errors[:date], "can't be blank"
  end
  
  test "should require amount" do
    transaction = build(:transaction, amount: nil)
    assert_not transaction.valid?
    assert_includes transaction.errors[:amount], "can't be blank"
  end
  
  test "should allow blank description" do
    transaction = build(:transaction, description: nil)
    assert transaction.valid?, "Description should be allowed to be blank"
    
    transaction = build(:transaction, description: "")
    assert transaction.valid?, "Description should be allowed to be empty string"
  end
  
  test "blank description should be flagged by anomaly detection" do
    transaction = create(:transaction, description: nil)
    
    # Trigger anomaly detection
    result = AnomalyDetection::DetectAllAnomalies.call(transaction: transaction)
    
    assert result.success?
    assert transaction.anomaly_flags.where(anomaly_type: 'missing_metadata').exists?,
           "Transaction with blank description should be flagged as missing metadata"
  end
  
  test "should clean description spaces before validation" do
    transaction = create(:transaction, description: "  Extra   Spaces  ")
    assert_equal "Extra Spaces", transaction.description
  end
  
  test "category is optional" do
    transaction = build(:transaction, category: nil)
    assert transaction.valid?
  end
  
  test "should mark as reviewed" do
    transaction = create(:transaction, :flagged)
    create(:anomaly_flag, transaction_record: transaction, resolved: false)
    
    transaction.mark_reviewed!
    
    assert transaction.reviewed?
    assert_not transaction.flagged?
    assert transaction.anomaly_flags.all?(&:resolved?)
  end
end
