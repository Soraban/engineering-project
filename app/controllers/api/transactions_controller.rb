module Api
  class TransactionsController < ApplicationController
    DEFAULT_PAGE_SIZE = 100

    def index
      transactions = Transaction.order(date: :desc, created_at: :desc).limit(DEFAULT_PAGE_SIZE)
      render json: transactions
    end

    def create
      transaction = Transaction.new(transaction_params)
      Transactions::RuleApplier.new(transaction).call

      if transaction.save
        render json: transaction, status: :created
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


    private

    def transaction_params
      params.require(:transaction).permit(:date, :description, :amount, :category)
    end
  end
end
