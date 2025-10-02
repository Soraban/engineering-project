class BulkAnomalyDetectorJob < ApplicationJob
  queue_as :default

  def perform(transaction_ids)
    AnomalyDetector.batch_detect(transaction_ids)
  end
end
