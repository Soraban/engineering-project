require 'csv'

class CsvImportJob < ApplicationJob
  queue_as :imports

  def perform(import_job_id, file_path)
    import_job = ImportJob.find(import_job_id)
    import_job.mark_as_processing!

    # Count total rows first (for progress tracking)
    total_rows = CSV.read(file_path, headers: true).length
    import_job.update!(total_rows: total_rows)

    # Process in batches of 100 to reduce memory and allow progress updates
    CSV.foreach(file_path, headers: true).each_slice(100) do |batch|
      # Check if job was cancelled
      import_job.reload
      if import_job.cancelled?
        Rails.logger.info "Import job #{import_job.id} was cancelled"
        break
      end

      # Use bulk insert for better performance
      transactions_to_create = []

      batch.each do |row|
        begin
          transaction_data = parse_row(row)
          transactions_to_create << transaction_data
        rescue => e
          import_job.add_row_error(row.to_h, [e.message])
          import_job.increment_processed!(success: false)
        end
      end

      # Bulk insert all valid transactions in this batch
      if transactions_to_create.any?
        begin
          # Insert without callbacks for performance
          inserted = Transaction.insert_all(
            transactions_to_create,
            returning: [:id]
          )

          # Queue background processing for the batch
          inserted.rows.flatten.each do |transaction_id|
            TransactionProcessorJob.perform_later(transaction_id)
          end

          # Update progress for the whole batch at once
          import_job.increment_processed_batch!(success_count: transactions_to_create.size)
        rescue => e
          # If bulk insert fails, fall back to individual inserts
          success_count = 0
          failed_count = 0

          transactions_to_create.each do |transaction_data|
            begin
              transaction = Transaction.create!(transaction_data)
              TransactionProcessorJob.perform_later(transaction.id)
              success_count += 1
            rescue => e
              import_job.add_row_error(transaction_data, [e.message])
              failed_count += 1
            end
          end

          import_job.increment_processed_batch!(success_count: success_count, failed_count: failed_count)
        end
      end
    end

    # Only mark as completed if not cancelled
    import_job.reload
    import_job.mark_as_completed! unless import_job.cancelled?

    # Clean up temp file
    File.delete(file_path) if File.exist?(file_path)

  rescue => e
    import_job.mark_as_failed!(e.message) if import_job
    # Clean up temp file
    File.delete(file_path) if File.exist?(file_path)
    raise e
  end

  private

  def parse_row(row)
    date = parse_date(row)
    description = row['description']&.strip
    amount = parse_amount(row['amount'])

    {
      transaction_date: date,
      description: description,
      amount: amount,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def parse_date(row)
    date_str = row['date'] || row['transaction_date']
    Date.parse(date_str.to_s)
  end

  def parse_amount(amount_str)
    amount_str.to_s.gsub(/[^\d.-]/, '').to_f
  end
end
