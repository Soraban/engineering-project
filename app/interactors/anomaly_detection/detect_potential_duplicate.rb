module AnomalyDetection
  class DetectPotentialDuplicate
    include Interactor

    def call
      transaction = context.transaction
      
      duplicates = find_potential_duplicates(transaction)
      return if duplicates.empty?

      details = {
        message: "Potential duplicate transaction(s) found",
        duplicate_ids: duplicates.pluck(:id),
        duplicate_count: duplicates.count
      }

      context.flag = AnomalyFlag.create_potential_duplicate(
        transaction: transaction,
        details: details
      )
    rescue => e
      context.fail!(error: e.message)
    end

    private

    def find_potential_duplicates(transaction)
      # Use description_hash for faster duplicate detection
      Transaction.where.not(id: transaction.id)
                 .where(date: transaction.date)
                 .where(amount: transaction.amount)
                 .where(description_hash: transaction.description_hash)
    end
  end
end

