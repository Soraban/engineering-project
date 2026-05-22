class CsvImportJob < ApplicationJob
  queue_as :default

  PREVIEW_LIMIT = 50

  def perform(user_id, csv_content, import_id)
    user = User.find(user_id)
    result = CsvImporter.new(user: user, csv_content: csv_content, import_id: import_id).import

    preview_ids = result.imported_ids.first(PREVIEW_LIMIT)
    preview_transactions = Transaction.where(id: preview_ids).includes(:anomalies).order(id: :desc)

    ActionCable.server.broadcast(
      "import_status_#{import_id}",
      {
        status: 'complete',
        imported: result.imported_count,
        errors: result.error_count,
        flagged: result.flagged_count,
        error_details: result.errors.first(50),
        preview: TransactionSerializer.render_as_json(preview_transactions, view: :detail),
        preview_limit: PREVIEW_LIMIT
      }
    )
  end
end
