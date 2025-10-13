class DashboardController < ApplicationController
  def index
    # Use cached stats for performance
    stats = TransactionStatsService.dashboard_stats
    @total_transactions = stats[:total_transactions]
    @uncategorized_count = stats[:uncategorized_count]
    @flagged_count = stats[:flagged_count]
    @unresolved_anomalies_count = stats[:unresolved_anomalies_count]

    # Recent transactions needing review (not cached - needs to be fresh)
    @needs_review = Transaction.includes(:anomaly_flags, :category)
                               .where('flagged = ? OR category_id IS NULL', true)
                               .recent
                               .limit(10)

    # Anomaly summary (cached)
    anomaly_breakdown = TransactionStatsService.anomaly_breakdown
    @anomalies_by_type = anomaly_breakdown[:by_type]
    @anomalies_by_severity = anomaly_breakdown[:by_severity]

    # Category distribution (cached)
    @category_stats = TransactionStatsService.category_stats(10)

    # Recent activity
    @recent_transactions = Transaction.includes(:category).recent.limit(5)
  end

  def review
    # Transactions needing review with pagination
    @transactions = Transaction.includes(:anomaly_flags, :category)
                               .left_joins(:anomaly_flags)
                               .where('transactions.flagged = ? OR transactions.category_id IS NULL OR anomaly_flags.resolved = ?', 
                                      true, false)
                               .distinct
                               .recent
                               .page(params[:page])
                               .per(25)

    # Filter options
    if params[:filter] == 'flagged'
      @transactions = @transactions.where(flagged: true)
    elsif params[:filter] == 'uncategorized'
      @transactions = @transactions.where(category_id: nil)
    elsif params[:filter] == 'anomalies'
      @transactions = @transactions.joins(:anomaly_flags).where('anomaly_flags.resolved = ?', false)
    end

    # Severity filter
    if params[:severity].present?
      @transactions = @transactions.joins(:anomaly_flags)
                                  .where('anomaly_flags.severity = ?', params[:severity])
    end

    @categories = Category.ordered
  end

  def approve_transaction
    transaction = Transaction.find(params[:id])
    transaction.mark_reviewed!
    
    respond_to do |format|
      format.html { redirect_to review_dashboard_path, notice: 'Transaction approved.' }
      format.json { head :ok }
    end
  end

  def bulk_approve
    if params[:transaction_ids].present?
      transaction_ids = params[:transaction_ids].split(',').map(&:to_i)
      Transaction.where(id: transaction_ids).find_each do |transaction|
        transaction.mark_reviewed!
      end
      
      respond_to do |format|
        format.html { redirect_to review_dashboard_path, notice: 'Transactions approved.' }
        format.json { head :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to review_dashboard_path, alert: 'Please select transactions.' }
        format.json { head :unprocessable_entity }
      end
    end
  end
end
