module AnomalyDetection
  class DetectUnusualAmount
    include Interactor

    def call
      transaction = context.transaction
      
      # Calculate average once and cache in context
      avg = context.user_average_amount ||= calculate_user_average(transaction)
      
      return unless unusual_amount?(transaction, avg)

      severity = calculate_severity(transaction, avg)
      details = {
        message: "Amount is significantly different from user's typical spending",
        average_amount: avg,
        deviation: calculate_deviation(transaction, avg)
      }

      context.flag = AnomalyFlag.create_unusual_amount(
        transaction: transaction,
        severity: severity,
        details: details
      )
    rescue => e
      context.fail!(error: e.message)
    end

    private

    def unusual_amount?(transaction, avg)
      return false if avg.zero?
      
      deviation = (transaction.amount - avg).abs / avg
      deviation > 2.0 # More than 200% deviation
    end

    def calculate_severity(transaction, avg)
      deviation = (transaction.amount - avg).abs / avg
      
      case deviation
      when 5.0.. then :critical
      when 3.0.. then :high
      when 2.0.. then :medium
      else :low
      end
    end

    def calculate_user_average(transaction)
      # Calculate once per batch (reused via context)
      Transaction.where.not(id: transaction.id)
                 .where('amount > 0')
                 .average(:amount)
                 .to_f
    end

    def calculate_deviation(transaction, avg)
      return 0 if avg.zero?
      ((transaction.amount - avg).abs / avg * 100).round(2)
    end
  end
end

