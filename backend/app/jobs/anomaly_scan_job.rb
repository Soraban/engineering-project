class AnomalyScanJob < ApplicationJob
  queue_as :default

  def perform(transaction_ids)
    Transaction.where(id: transaction_ids).find_each do |transaction|
      AnomalyDetector.check(transaction)
    end
  end
end
