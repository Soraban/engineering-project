module AnomalyDetection
  class DetectMissingMetadata
    include Interactor

    def call
      transaction = context.transaction
      
      return unless missing_metadata?(transaction)

      details = {
        message: "Transaction has missing or incomplete information",
        missing_fields: collect_missing_fields(transaction)
      }

      context.flag = AnomalyFlag.create_missing_metadata(
        transaction: transaction,
        details: details
      )
    rescue => e
      context.fail!(error: e.message)
    end

    private

    def missing_metadata?(transaction)
      transaction.description.blank? || 
      transaction.category.blank?
    end

    def collect_missing_fields(transaction)
      fields = []
      fields << 'description' if transaction.description.blank?
      fields << 'category' if transaction.category.blank?
      fields
    end
  end
end

