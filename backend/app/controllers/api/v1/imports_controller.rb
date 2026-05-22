class Api::V1::ImportsController < Api::V1::BaseController
  def create
    file = params[:file]

    unless file.present? && file.content_type.in?(%w[text/csv application/csv application/vnd.ms-excel])
      return render_error('Please upload a valid CSV file', status: :unprocessable_entity)
    end

    # Accept a client-generated import_id so the frontend can subscribe to the
    # status channel BEFORE the job is enqueued. Without this, small CSVs can
    # finish processing and broadcast 'complete' before the WebSocket
    # subscription is confirmed — the broadcast lands on zero subscribers and
    # the UI spinner spins forever even though the data is in the DB.
    import_id = params[:import_id].presence || SecureRandom.uuid

    # Read the upload into memory here in the web process. Don't pass a tempfile
    # path to Sidekiq — on Render (and any multi-container deploy) the worker
    # runs in a different container and won't see /tmp/* from the web container.
    csv_content = file.read.force_encoding('UTF-8')
    CsvImportJob.perform_later(current_user.id, csv_content, import_id)

    render json: { message: 'Import started', import_id: import_id }, status: :accepted
  end
end
