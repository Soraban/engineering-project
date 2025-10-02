class TransactionProcessorJob < ApplicationJob
  queue_as :default

  def perform(transaction_id)
    transaction = Transaction.find(transaction_id)
    RuleEngine.apply_to_transaction(transaction)
    AnomalyDetector.check_transaction(transaction)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "Transaction #{transaction_id} not found for processing"
  end
end
