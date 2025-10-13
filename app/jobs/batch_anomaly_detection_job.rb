class BatchAnomalyDetectionJob < ApplicationJob
  queue_as :default

  def perform(transaction_ids, import_id: nil, batch_num: nil, total_batches: nil)
    return if transaction_ids.blank?

    # Bulk load all transactions at once (avoid N+1)
    transactions = Transaction.where(id: transaction_ids).to_a
    return if transactions.empty?
    
    # Pre-calculate data once for the entire batch
    user_average = Transaction.where('amount > 0').average(:amount).to_f
    
    # Track which transactions need to be flagged
    flagged_transaction_ids = []
    
    # Process anomaly detection for each transaction
    transactions.each do |transaction|
      # Detect anomalies, passing the pre-calculated average
      result = AnomalyDetection::DetectAllAnomalies.call(
        transaction: transaction,
        user_average_amount: user_average
      )
      
      if result.success?
        # Check if any anomalies were found (flags are in context)
        if result.flags.any?
          flagged_transaction_ids << transaction.id
        end
      else
        Rails.logger.error("Anomaly detection failed for transaction #{transaction.id}: #{result.error}")
      end
    end
    
    # Bulk update flagged status (single query instead of N queries)
    if flagged_transaction_ids.any?
      Transaction.where(id: flagged_transaction_ids).update_all(flagged: true)
    end
    
    # Update import status if this is part of an import
    if import_id && batch_num && total_batches
      update_anomaly_progress(import_id, batch_num, total_batches)
    end
  end
  
  private
  
  def update_anomaly_progress(import_id, batch_num, total_batches)
    # Use a separate cache key to track completed batches (thread-safe increment)
    completed_key = "import_anomaly_completed:#{import_id}"
    
    # Increment completed count atomically
    completed_count = Rails.cache.increment(completed_key, 1, expires_in: 1.hour) || 1
    Rails.cache.write(completed_key, completed_count, expires_in: 1.hour) unless Rails.cache.exist?(completed_key)
    completed_count = Rails.cache.read(completed_key) || batch_num
    
    status = Rails.cache.read("import_status:#{import_id}")
    return unless status
    
    # DON'T broadcast if import is still in 'importing' phase
    # Wait until TransactionImportJob switches to 'anomaly_detection' phase
    if status['phase'] == 'importing'
      Rails.logger.info "[Import #{import_id}] Anomaly batch #{completed_count}/#{total_batches} complete (waiting for import to finish before broadcasting)"
      return
    end
    
    # Update with anomaly detection progress (use completed count, not batch number)
    updated_status = status.merge({
      'anomaly_batch' => completed_count,
      'anomaly_total_batches' => total_batches
    })
    
    # Keep status as processing while anomaly detection runs
    if completed_count < total_batches
      updated_status['status'] = 'processing'
      updated_status['phase'] = 'anomaly_detection'
    else
      # All batches complete - mark as fully complete
      updated_status['status'] = 'completed'
      updated_status['phase'] = 'anomaly_detection_complete'
      # Clean up the counter
      Rails.cache.delete(completed_key)
    end
    
    Rails.cache.write("import_status:#{import_id}", updated_status, expires_in: 1.hour)
    
    # Broadcast update
    broadcast_anomaly_update(import_id, updated_status)
    
    Rails.logger.info "[Import #{import_id}] Anomaly detection: #{completed_count}/#{total_batches} batches complete"
  end
  
  def broadcast_anomaly_update(import_id, status)
    return if Rails.env.test?
    
    Turbo::StreamsChannel.broadcast_replace_to(
      "import_#{import_id}",
      target: "status-card",
      partial: "transactions/import_status_card",
      locals: { status: status }
    )
  rescue => e
    Rails.logger.error "[Import #{import_id}] Anomaly broadcast failed: #{e.message}"
  end
end

