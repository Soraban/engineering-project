module Transactions
  class AnomalyDetector
    STDDEV_MULTIPLIER = 2.5
    MIN_HISTORY_COUNT = 25

    def self.call(transaction, amount_stats: nil)
      new(transaction, amount_stats: amount_stats).call
    end

    def self.amount_stats(exclude_id: nil)
      scope = Transaction.where.not(amount: nil)
      scope = scope.where.not(id: exclude_id) if exclude_id

      count, avg, stddev =
        scope.pick(Arel.sql("COUNT(*), AVG(amount), STDDEV_SAMP(amount)"))

      {
        count: count.to_i,
        avg: avg&.to_d,
        stddev: stddev&.to_d
      }
    end

    def initialize(transaction, amount_stats: nil)
      @tx = transaction
      @amount_stats = amount_stats
    end

    def call
      reasons = []
      reasons << "missing_metadata" if missing_metadata?
      reasons << "potential_duplicate" if potential_duplicate?
      reasons << "unusual_amount" if unusual_amount?

      return @tx if reasons.empty?

      existing = @tx.flag_reason.to_s.split(",").map(&:strip).reject(&:blank?)
      merged = (existing + reasons).uniq

      @tx.update!(flagged: true, flag_reason: merged.join(","))

      @tx
    end


    private

    def missing_metadata?
      @tx.description.blank? || @tx.date.blank? || @tx.amount.blank?
    end

    def potential_duplicate?
      Transaction
        .where(date: @tx.date, amount: @tx.amount, description: @tx.description)
        .where.not(id: @tx.id)
        .exists?
    end

    def unusual_amount?
      return false if @tx.amount.blank?

      stats = @amount_stats || self.class.amount_stats(exclude_id: @tx.id)
      return false if stats[:count] < MIN_HISTORY_COUNT
      return false if stats[:stddev].nil? || stats[:stddev].zero?

      threshold = stats[:avg] + (stats[:stddev] * STDDEV_MULTIPLIER)
      @tx.amount.to_d > threshold
    end
  end
end
