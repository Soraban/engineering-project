class TransactionsController < ApplicationController
  before_action :set_transaction, only: [:show, :edit, :update, :destroy]

  def index
    @transactions = Transaction.includes(:anomaly_flags, :category)
                               .order(date: :desc)
                               .page(params[:page])
                               .per(50)

    # Apply filters
    @transactions = @transactions.by_category(params[:category]) if params[:category].present?
    @transactions = @transactions.by_status(params[:status]) if params[:status].present?
    @transactions = @transactions.flagged if params[:flagged] == 'true'
    @transactions = @transactions.uncategorized if params[:uncategorized] == 'true'
    
    if params[:start_date].present? && params[:end_date].present?
      @transactions = @transactions.by_date_range(params[:start_date], params[:end_date])
    end

    @categories = Category.ordered
  end

  def show
    @anomaly_flags = @transaction.anomaly_flags.recent
  end

  def new
    @transaction = Transaction.new
    @categories = Category.ordered
  end

  def create
    transaction, results = TransactionCreationService.create_single(transaction_params)

    if transaction
      redirect_to transaction, notice: 'Transaction was successfully created.'
    else
      @transaction = Transaction.new(transaction_params)
      @categories = Category.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = Category.ordered
  end

  def update
    if @transaction.update(transaction_params)
      redirect_to @transaction, notice: 'Transaction was successfully updated.'
    else
      @categories = Category.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction.destroy
    redirect_to transactions_url, notice: 'Transaction was successfully deleted.'
  end

  def import
    if request.post?
      if params[:file].present?
        begin
          # Generate import ID first
          import_id = SecureRandom.uuid
          
          # Initialize status IMMEDIATELY (so page loads with something)
          Rails.cache.write("import_status:#{import_id}", {
            'status' => 'queued',
            'started_at' => Time.current.to_s
          }, expires_in: 1.hour)
          
          # Get uploaded file - it's already on disk as a tempfile
          uploaded_file = params[:file]
          
          # Move the tempfile to our location (instant - just renames on same filesystem)
          temp_path = Rails.root.join('tmp', "import_#{import_id}.csv")
          FileUtils.mv(uploaded_file.tempfile.path, temp_path)
          
          # Determine queue based on file size (fast - no parsing)
          file_size_kb = File.size(temp_path) / 1024.0
          queue_name = file_size_kb < 100 ? :small_import : :large_import
          
          # Enqueue to appropriate queue (non-blocking)
          TransactionImportJob.set(queue: queue_name)
                              .perform_later(temp_path.to_s, import_id)
          
          redirect_to import_status_transactions_path(import_id)
        rescue => e
          File.delete(temp_path) if File.exist?(temp_path)
          flash[:alert] = "Import failed: #{e.message}"
          render :import
        end
      else
        flash[:alert] = 'Please select a CSV file to import'
        render :import
      end
    end
  end

  def import_status
    @import_id = params[:id]
    @status = Rails.cache.read("import_status:#{@import_id}")
    
    if @status.nil?
      respond_to do |format|
        format.html do
          flash[:alert] = "Import status not found or expired"
          redirect_to transactions_path
        end
        format.json { render json: { error: "Import status not found or expired" }, status: :not_found }
      end
      return
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @status }
    end
  end

  def bulk_categorize
    if params[:transaction_ids].present? && params[:category_id].present?
      transaction_ids = params[:transaction_ids].split(',').map(&:to_i)
      Transaction.bulk_categorize(transaction_ids, params[:category_id])
      
      respond_to do |format|
        format.html { redirect_to transactions_path, notice: 'Transactions categorized successfully.' }
        format.json { head :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to transactions_path, alert: 'Please select transactions and a category.' }
        format.json { head :unprocessable_entity }
      end
    end
  end

  private

  def set_transaction
    @transaction = Transaction.find(params[:id])
  end

  def transaction_params
    params.require(:transaction).permit(:date, :description, :amount, :category_id, :status)
  end

  def count_csv_rows(file_path)
    # Fast line count without CSV parsing 
    File.foreach(file_path).count 
  end

  def import_queue_for_size(row_count)
    row_count < 1000 ? :small_import : :large_import
  end
end
