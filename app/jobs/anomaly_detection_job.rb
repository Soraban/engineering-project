class AnomalyDetectionJob < ApplicationJob
  queue_as :default

  def perform(transaction_id)
    transaction = Transaction.find_by(id: transaction_id)
    return unless transaction

    # Detect anomalies for this transaction
    detect_for_transaction(transaction)

    # Reload the association to get newly created flags
    transaction.anomaly_flags.reload
    
    # Flag the transaction if any anomalies were found
    if transaction.anomaly_flags.unresolved.any?
      transaction.update!(flagged: true)
    end
  end

  def detect_for_transaction(transaction)
    # Use interactor to orchestrate all anomaly detection
    result = AnomalyDetection::DetectAllAnomalies.call(transaction:)

    if result.success?
      result.flags
    else
      Rails.logger.error("Anomaly detection failed: #{result.error}")
      []
    end
  end
end
