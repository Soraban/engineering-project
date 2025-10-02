class ImportJob < ApplicationRecord
  # Status: pending, processing, completed, failed, cancelled
  validates :status, inclusion: { in: %w[pending processing completed failed cancelled] }

  def progress_percentage
    return 0 if total_rows.zero?
    ((processed_rows.to_f / total_rows) * 100).round(2)
  end

  def increment_processed!(success: true, count: 1)
    if success
      self.successful_rows += count
    else
      self.failed_rows += count
    end
    self.processed_rows += count
    save!
  end

  def increment_processed_batch!(success_count: 0, failed_count: 0)
    self.successful_rows += success_count
    self.failed_rows += failed_count
    self.processed_rows += (success_count + failed_count)
    save!
  end

  def mark_as_processing!
    update!(status: 'processing', started_at: Time.current)
  end

  def mark_as_completed!
    update!(status: 'completed', completed_at: Time.current)
  end

  def mark_as_failed!(error_message)
    update!(
      status: 'failed',
      completed_at: Time.current,
      error_log: (error_log || []) + [{ message: error_message, timestamp: Time.current }]
    )
  end

  def mark_as_cancelled!
    update!(status: 'cancelled', completed_at: Time.current)
  end

  def cancelled?
    status == 'cancelled'
  end

  def add_row_error(row_data, error_messages)
    self.error_log ||= []
    self.error_log << {
      row: row_data,
      errors: error_messages,
      timestamp: Time.current
    }
    save!
  end
end
