class TransactionStatsService
  CACHE_EXPIRY = 5.minutes

  class << self
    # Get dashboard stats with caching
    def dashboard_stats
      Rails.cache.fetch('dashboard_stats', expires_in: CACHE_EXPIRY) do
        {
          total_transactions: Transaction.count,
          uncategorized_count: Transaction.uncategorized.count,
          flagged_count: Transaction.flagged.count,
          unresolved_anomalies_count: AnomalyFlag.unresolved.count
        }
      end
    end

    # Get anomaly breakdown with caching
    def anomaly_breakdown
      Rails.cache.fetch('anomaly_breakdown', expires_in: CACHE_EXPIRY) do
        {
          by_type: AnomalyFlag.unresolved.group(:anomaly_type).count,
          by_severity: AnomalyFlag.unresolved.group(:severity).count
        }
      end
    end

    # Get category statistics with caching
    def category_stats(limit = 10)
      Rails.cache.fetch("category_stats_#{limit}", expires_in: CACHE_EXPIRY) do
        # Use pluck to get raw data without instantiating ActiveRecord objects
        result = Transaction.joins(:category)
                           .group('categories.name')
                           .order(Arel.sql('COUNT(*) DESC'))
                           .limit(limit)
                           .pluck('categories.name', Arel.sql('COUNT(*)'), Arel.sql('SUM(amount)'))
        
        result.map { |name, count, total| OpenStruct.new(category: name, count: count, total: total) }
      end
    end

    # Clear all stat caches
    def clear_caches
      Rails.cache.delete('dashboard_stats')
      Rails.cache.delete('anomaly_breakdown')
      Rails.cache.delete_matched('category_stats_*')
    end

    # Get spending trends (cached)
    def spending_trends(days = 30)
      cache_key = "spending_trends_#{days}_#{Date.today}"
      
      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        start_date = days.days.ago.to_date
        
        Transaction.where('date >= ?', start_date)
                   .group('date')
                   .select('date, SUM(amount) as total_amount, COUNT(*) as transaction_count')
                   .order('date ASC')
                   .to_a
      end
    end

    # Get transaction count by date range (optimized)
    def count_by_date_range(start_date, end_date)
      cache_key = "transaction_count_#{start_date}_#{end_date}"
      
      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        Transaction.where(date: start_date..end_date).count
      end
    end
  end
end

