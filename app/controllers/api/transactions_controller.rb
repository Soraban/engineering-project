module Api
  class TransactionsController < ApplicationController
    DEFAULT_PAGE_SIZE = 100

    def index
      limit  = (params[:limit] || DEFAULT_PAGE_SIZE).to_i.clamp(1, 500)
      offset = (params[:offset] || 0).to_i

      transactions = Transaction
        .order(date: :desc, created_at: :desc)
        .limit(limit)
        .offset(offset)

      render json: transactions
    end

    def create
      transaction = Transaction.new(transaction_params)
      Transactions::RuleApplier.new(transaction).call

      if transaction.save
        Transactions::AnomalyDetector.new(transaction).call
        render json: transaction.reload, status: :created
      else
        render json: { errors: transaction.errors.full_messages }, status: :unprocessable_content
      end
    end

    def import
      file = params[:file]
      return render json: { errors: [ "No file uploaded" ] }, status: :unprocessable_content if file.nil?

      result = Transactions::CsvImporter.new(file: file).call
      render json: result, status: :ok
    rescue Transactions::CsvImporter::MalformedCsvError
      render json: { errors: [ "Invalid CSV file" ] }, status: :unprocessable_content
    end

    def bulk_update
      ids = Array(params[:transaction_ids])
        .filter_map { |id| Integer(id, exception: false) }
        .uniq

      category = params[:category].to_s

      if ids.empty?
        return render json: { errors: [ "No transactions selected" ] }, status: :unprocessable_content
      end

      # Require category for bulk update.
      if category.strip.empty?
        return render json: { errors: [ "Category is required" ] }, status: :unprocessable_content
      end

      updated_count =
        Transaction
          .where(id: ids)
          .update_all(category: category.strip, updated_at: Time.current)

      render json: { updated: updated_count }, status: :ok
    end

    def review
      limit  = (params[:limit] || DEFAULT_PAGE_SIZE).to_i.clamp(1, 500)

      flagged = Transaction.where(flagged: true)
                           .order(date: :desc, created_at: :desc)
                           .limit(limit)

      uncategorized = Transaction.where(category: [ nil, "" ])
                                 .order(date: :desc, created_at: :desc)
                                 .limit(limit)

      render json: { flagged: flagged, uncategorized: uncategorized }, status: :ok
    end

    def update
      transaction = Transaction.find(params[:id])

      flagged_param_present = params[:transaction]&.key?(:flagged)
      flagged_cast = ActiveModel::Type::Boolean.new.cast(params.dig(:transaction, :flagged))
      approving = flagged_param_present && (flagged_cast == false)

      if transaction.update(transaction_params)
        if approving
          transaction.update!(flagged: false, flag_reason: nil)
        else
          Transactions::RuleApplier.new(transaction).call
          transaction.save!
          Transactions::AnomalyDetector.new(transaction).call
        end

        render json: transaction.reload, status: :ok
      else
        render json: { errors: transaction.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      Transaction.find(params[:id]).destroy!
      head :no_content
    end

    private

    def transaction_params
      params.require(:transaction).permit(:date, :description, :amount, :category, :flagged)
    end
  end
end
