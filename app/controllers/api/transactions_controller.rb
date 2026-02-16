module Api
  class TransactionsController < ApplicationController
    DEFAULT_PAGE_SIZE = 100

    def index
      transactions = Transaction.order(date: :desc, created_at: :desc).limit(DEFAULT_PAGE_SIZE)
      render json: transactions
    end

    def create
      transaction = Transaction.new(transaction_params)

      if transaction.save
        render json: transaction, status: :created
      else
        render json: { errors: transaction.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def transaction_params
      params.require(:transaction).permit(:date, :description, :amount, :category)
    end
  end
end
