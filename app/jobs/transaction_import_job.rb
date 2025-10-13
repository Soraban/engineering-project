class TransactionImportJob < ApplicationJob
  queue_as :default

  DEFAULT_BATCH_SIZE = 500

  # Retry up to 5 times with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(file_path, import_id, start_offset: 0, batch_size: DEFAULT_BATCH_SIZE)
    Rails.logger.info "[Import #{import_id}] Starting import from #{file_path}"
    
    # Check if we're resuming from a previous attempt
    if start_offset > 0
      Rails.logger.info "[Import #{import_id}] Resuming from offset #{start_offset}"
    end
    
    # Update status to processing
    update_status(import_id, status: 'processing', phase: 'importing')
    
    # Initialize tracking
    parser = TransactionCsvParser.new(file_path)
    service = TransactionCreationService.new
    current_offset = start_offset
    total_batches = 0
    
    # Process each batch with checkpoint tracking
    parser.each_batch(start_offset:, batch_size:) do |batch_data, offset, batch_size|
      next if batch_data.empty?
      
      # Import this batch (anomaly detection enqueued at the end)
      service.create_bulk(batch_data)
      
      # Update checkpoint after successful batch
      current_offset = offset + batch_size
      total_batches += 1
      
      # Update progress and broadcast after EACH batch
      update_status(import_id, 
        status: 'processing',
        phase: 'importing',
        processed: service.results[:success],
        batch: total_batches
      )
      
      Rails.logger.info "Successfully processed batch #{total_batches} (offset: #{current_offset})"
    end
    
    # Import complete - NOW enqueue ALL anomaly detection jobs at once
    imported_ids = service.results[:imported_ids]
    
    # Calculate total anomaly batches
    total_anomaly_batches = (imported_ids.size.to_f / 100).ceil
    
    # Enqueue all anomaly detection jobs with correct total count
    enqueue_anomaly_detection(imported_ids, import_id: import_id)
    
    # Switch to anomaly detection phase
    update_status(import_id,
      status: 'processing',
      phase: 'anomaly_detection',
      success: service.results[:success],
      errors: service.results[:errors],
      imported_ids: imported_ids,
      total_batches_processed: total_batches,
      anomaly_batch: 0,
      anomaly_total_batches: total_anomaly_batches
    )
    
    # Note: Anomaly detection jobs are already enqueued by the service
    # They run asynchronously, so we mark import as completed
    
    # Store successful completion in cache
    Rails.cache.write("import_status:#{import_id}", {
      'status' => 'completed',
      'phase' => 'anomaly_detection_running',
      'success' => service.results[:success],
      'errors' => service.results[:errors],
      'imported_ids' => imported_ids,
      'total_batches_processed' => total_batches,
      'completed_at' => Time.current.to_s
    }, expires_in: 1.hour)
    
    # Clean up the temp file only on full success
    File.delete(file_path) if File.exist?(file_path)
    
  rescue => e
    # Store error status with checkpoint info
    Rails.cache.write("import_status:#{import_id}", {
      'status' => 'failed',
      'error' => e.message,
      'last_successful_offset' => current_offset,
      'partial_success' => service&.results&.dig(:success) || 0,
      'imported_ids' => service&.results&.dig(:imported_ids) || [],
      'completed_at' => Time.current.to_s
    }, expires_in: 1.hour)
    
    Rails.logger.error "Import #{import_id} failed at offset #{current_offset}: #{e.message}"
    
    # If we have a checkpoint and haven't exceeded retry attempts, retry from checkpoint
    if current_offset > start_offset && executions < 5
      Rails.logger.info "Will retry import #{import_id} from offset #{current_offset}"
      # Re-enqueue with checkpoint - let retry_on handle the timing
      raise
    else
      # Final failure - clean up temp file
      File.delete(file_path) if File.exist?(file_path)
      raise
    end
  end
  
  # Override retry with checkpoint awareness
  def retry_job(options = {})
    # Get the last successful offset from cache
    import_id = arguments[1]
    status = Rails.cache.read("import_status:#{import_id}") || {}
    last_offset = status[:last_successful_offset] || arguments[2] || 0
    
    # Update arguments with new offset
    self.arguments = [arguments[0], import_id, last_offset]
    
    super(options)
  end
  
  private
  
  def update_status(import_id, updates)
    current_status = Rails.cache.read("import_status:#{import_id}") || {}
    new_status = current_status.merge(updates.stringify_keys)
    
    # Update cache
    Rails.cache.write("import_status:#{import_id}", new_status, expires_in: 1.hour)
    
    # Log progress
    Rails.logger.info "[Import #{import_id}] #{new_status['status']}/#{new_status['phase']} - #{new_status['processed'] || new_status['success']} records"
    
    # Broadcast via Turbo Streams (WebSocket)
    broadcast_update(import_id, new_status)
  end
  
  def broadcast_update(import_id, status)
    # Skip in test environment
    return if Rails.env.test?
    
    Turbo::StreamsChannel.broadcast_replace_to(
      "import_#{import_id}",
      target: "status-card",
      partial: "transactions/import_status_card",
      locals: { status: status }
    )
  rescue => e
    # Don't fail the job if broadcast fails
    Rails.logger.error "[Import #{import_id}] Broadcast failed: #{e.message}"
  end
  
  def enqueue_anomaly_detection(transaction_ids, import_id:)
    # Enqueue anomaly detection in batches for better performance
    batches = transaction_ids.each_slice(100).to_a
    
    batches.each_with_index do |batch_ids, index|
      BatchAnomalyDetectionJob.perform_later(
        batch_ids, 
        import_id: import_id, 
        batch_num: index + 1, 
        total_batches: batches.count
      )
    end
  end
end

