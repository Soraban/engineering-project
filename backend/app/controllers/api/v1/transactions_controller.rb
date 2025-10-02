module Api
  module V1
    class TransactionsController < ApplicationController
      before_action :set_transaction, only: [:show, :update, :destroy]

      # GET /api/v1/transactions
      def index
        @transactions = Transaction.includes(:category)
                                  .order(transaction_date: :desc)
                                  .page(params[:page])
                                  .per(params[:per_page] || 50)

        # Apply filters
        @transactions = @transactions.where(category_id: params[:category_id]) if params[:category_id]
        @transactions = @transactions.flagged if params[:flagged] == 'true'
        @transactions = @transactions.uncategorized if params[:uncategorized] == 'true'

        render json: {
          transactions: @transactions.as_json(include: :category),
          meta: pagination_meta(@transactions)
        }
      end

      # GET /api/v1/transactions/:id
      def show
        render json: @transaction.as_json(include: :category)
      end

      # POST /api/v1/transactions
      def create
        @transaction = Transaction.new(transaction_params)

        if @transaction.save
          # Apply rules and anomaly detection to manually created transactions
          RuleEngine.apply_to_transaction(@transaction)
          AnomalyDetector.check_transaction(@transaction)

          render json: @transaction.as_json(include: :category), status: :created
        else
          render json: { errors: @transaction.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/transactions/:id
      def update
        if @transaction.update(transaction_params)
          render json: @transaction.as_json(include: :category)
        else
          render json: { errors: @transaction.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/transactions/:id
      def destroy
        @transaction.destroy
        head :no_content
      end

      # DELETE /api/v1/transactions/destroy_all
      def destroy_all
        Transaction.delete_all
        render json: { message: 'All transactions deleted' }, status: :ok
      end

      # POST /api/v1/transactions/import
      def import
        unless params[:file]
          return render json: { error: 'No file provided' }, status: :bad_request
        end

        # Create import job record
        import_job = ImportJob.create!(
          status: 'pending',
          filename: params[:file].original_filename
        )

        # Save uploaded file to persistent temp location
        temp_dir = Rails.root.join('tmp', 'imports')
        FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)

        temp_file_path = temp_dir.join("import_#{import_job.id}_#{Time.current.to_i}.csv")
        File.open(temp_file_path, 'wb') do |file|
          file.write(params[:file].read)
        end

        # Queue the import job
        CsvImportJob.perform_later(import_job.id, temp_file_path.to_s)

        render json: {
          import_job_id: import_job.id,
          status: import_job.status,
          message: "Import started. Use the import_job_id to check progress."
        }, status: :accepted
      end

      # GET /api/v1/transactions/active_imports
      def active_imports
        import_jobs = ImportJob.where(status: ['pending', 'processing'])
                               .order(created_at: :desc)

        render json: import_jobs.map { |job|
          {
            id: job.id,
            status: job.status,
            filename: job.filename,
            total_rows: job.total_rows,
            processed_rows: job.processed_rows,
            successful_rows: job.successful_rows,
            failed_rows: job.failed_rows,
            progress_percentage: job.progress_percentage,
            errors: (job.error_log || []).last(10),
            started_at: job.started_at,
            completed_at: job.completed_at
          }
        }
      end

      # GET /api/v1/transactions/import_status/:id
      def import_status
        import_job = ImportJob.find(params[:id])

        render json: {
          id: import_job.id,
          status: import_job.status,
          filename: import_job.filename,
          total_rows: import_job.total_rows,
          processed_rows: import_job.processed_rows,
          successful_rows: import_job.successful_rows,
          failed_rows: import_job.failed_rows,
          progress_percentage: import_job.progress_percentage,
          errors: (import_job.error_log || []).last(10), # Only show last 10 errors
          started_at: import_job.started_at,
          completed_at: import_job.completed_at
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Import job not found' }, status: :not_found
      end

      # POST /api/v1/transactions/cancel_import/:id
      def cancel_import
        import_job = ImportJob.find(params[:id])

        if import_job.status == 'processing' || import_job.status == 'pending'
          import_job.mark_as_cancelled!
          render json: { message: 'Import cancelled' }, status: :ok
        else
          render json: { error: 'Import cannot be cancelled in current status' }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Import job not found' }, status: :not_found
      end

      # POST /api/v1/transactions/bulk_categorize
      def bulk_categorize
        unless params[:transaction_ids] && params[:category_id]
          return render json: { error: 'Missing required parameters' }, status: :bad_request
        end

        result = RuleEngine.bulk_categorize(params[:transaction_ids], params[:category_id])

        render json: {
          message: "Bulk categorization completed",
          updated_count: result[:updated_count]
        }
      end

      # GET /api/v1/transactions/review_dashboard
      def review_dashboard
        data = Rails.cache.fetch('review_dashboard', expires_in: 5.minutes) do
          {
            uncategorized: Transaction.uncategorized.count,
            flagged_anomalies: Transaction.flagged.count,
            needs_review: Transaction.needs_review.count,
            uncategorized_transactions: Transaction.uncategorized
                                                  .order(transaction_date: :desc)
                                                  .limit(10)
                                                  .as_json(include: :category),
            flagged_transactions: Transaction.flagged
                                            .order(transaction_date: :desc)
                                            .limit(10)
                                            .as_json(include: :category)
          }
        end

        render json: data
      end

      private

      def set_transaction
        @transaction = Transaction.find(params[:id])
      end

      def transaction_params
        params.require(:transaction).permit(
          :transaction_date,
          :description,
          :amount,
          :category_id,
          :reviewed,
          :flagged_as_anomaly,
          :anomaly_reason,
          metadata: {}
        )
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          next_page: collection.next_page,
          prev_page: collection.prev_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count
        }
      end
    end
  end
end
