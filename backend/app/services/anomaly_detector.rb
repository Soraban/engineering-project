class AnomalyDetector
  LARGE_AMOUNT_THRESHOLD = 1000
  DUPLICATE_TIME_WINDOW = 7.days

  def self.check_transaction(transaction)
    anomalies = []

    # Check for unusually large amounts
    if large_amount?(transaction)
      anomalies << "Large amount: $#{transaction.amount}"
    end

    # Check for potential duplicates
    if potential_duplicate?(transaction)
      anomalies << "Potential duplicate transaction"
    end

    # Check for missing metadata
    if missing_description?(transaction)
      anomalies << "Missing transaction description"
    end

    # Check for unusual spending patterns
    if unusual_for_user?(transaction)
      anomalies << "Unusual spending pattern detected"
    end

    if anomalies.any?
      transaction.update(
        flagged_as_anomaly: true,
        anomaly_reason: anomalies.join('; ')
      )
    end
  end

  def self.large_amount?(transaction)
    transaction.amount.abs > LARGE_AMOUNT_THRESHOLD
  end

  def self.potential_duplicate?(transaction)
    Transaction.where(
      transaction_date: transaction.transaction_date,
      amount: transaction.amount
    ).where.not(id: transaction.id)
    .where('created_at > ?', DUPLICATE_TIME_WINDOW.ago)
    .exists?
  end

  def self.missing_description?(transaction)
    transaction.description.blank?
  end

  def self.unusual_for_user?(transaction)
    # Get average and standard deviation of amounts
    stats = Transaction.where('created_at < ?', transaction.created_at)
                      .where('created_at > ?', 90.days.ago)
                      .pluck(:amount)

    return false if stats.size < 10

    mean = stats.sum / stats.size
    variance = stats.map { |x| (x - mean) ** 2 }.sum / stats.size
    std_dev = Math.sqrt(variance)

    # Use a minimum threshold based on percentage of mean for small amounts
    # This prevents false positives when amounts are low
    min_threshold = mean.abs * 0.5  # 50% of mean
    threshold = [3 * std_dev, min_threshold].max

    # Flag if amount is more than threshold from mean
    (transaction.amount - mean).abs > threshold
  rescue
    false
  end

  def self.batch_detect(transaction_ids)
    transactions = Transaction.where(id: transaction_ids)
    transactions.each { |t| check_transaction(t) }
  end
end
