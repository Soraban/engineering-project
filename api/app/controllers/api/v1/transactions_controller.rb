module Api
  module V1
    class TransactionsController < ::ApplicationController
      def index
        @transactions = ::Transaction.includes(:category)
                                   .order(date: :desc)
                                   .page(params[:page])
                                   .per(params[:per_page] || 100)

        render json: {
          transactions: @transactions,
          pagination: {
            current_page: @transactions.current_page,
            next_page: @transactions.next_page,
            prev_page: @transactions.prev_page,
            total_pages: @transactions.total_pages,
            total_count: @transactions.total_count
          }
        }
      end

      def create
        @transaction = ::Transaction.new(transaction_params)
        
        if @transaction.save
          @transaction.apply_rules
          render json: @transaction, status: :created
        else
          render json: { errors: @transaction.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def import
        service = TransactionImportService.new(params[:file])
        result = service.import
      
        if result[:errors].empty?
          render json: {
            message: "Successfully imported #{result[:imported]} transactions",
            imported: result[:imported],
            failed: result[:failed]
          }, status: :ok
        else
          render json: {
            message: "Import completed with errors",
            imported: result[:imported],
            failed: result[:failed],
            errors: result[:errors]
          }, status: :unprocessable_entity
        end
      end

      private

      def transaction_params
        params.require(:transaction).permit(:date, :description, :amount, :category_id, :flagged)
      end
    end
  end
end