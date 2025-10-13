module AnomalyDetection
  class DetectSuspiciousPattern
    include Interactor

    def call
      transaction = context.transaction
      
      return unless suspicious_pattern?(transaction)

      details = {
        message: "Transaction matches suspicious pattern",
        pattern_details: detect_pattern_details(transaction)
      }

      context.flag = AnomalyFlag.create_suspicious_pattern(
        transaction: transaction,
        details: details
      )
    rescue => e
      context.fail!(error: e.message)
    end

    private

    def suspicious_pattern?(transaction)
      # Check for round numbers which might be manual entries or fraudulent
      return true if round_number_pattern?(transaction)
      
      # Check for rapid sequential transactions
      rapid_transaction_pattern?(transaction)
    end

    def round_number_pattern?(transaction)
      transaction.amount % 100 == 0 && transaction.amount >= 500
    end

    def rapid_transaction_pattern?(transaction)
      recent_similar = Transaction.where('date >= ?', transaction.date - 1.day)
                                  .where('date <= ?', transaction.date + 1.day)
                                  .where('amount BETWEEN ? AND ?', 
                                         transaction.amount * 0.9, 
                                         transaction.amount * 1.1)
                                  .where.not(id: transaction.id)
      
      recent_similar.count >= 3
    end

    def detect_pattern_details(transaction)
      details = {}
      
      if round_number_pattern?(transaction)
        details[:round_number] = true
        details[:amount] = transaction.amount
      end
      
      if rapid_transaction_pattern?(transaction)
        details[:rapid_transactions] = true
      end
      
      details
    end
  end
end

