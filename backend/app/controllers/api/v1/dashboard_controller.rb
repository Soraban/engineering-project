class Api::V1::DashboardController < Api::V1::BaseController
  NEEDS_ATTENTION_LIMIT = 20
  ALLOWED_FILTERS = %w[all anomalies uncategorized high medium low].freeze
  ALLOWED_SORTS = %w[created_at id date amount].freeze
  ALLOWED_DIRECTIONS = %w[asc desc].freeze
  ALLOWED_SPENDING_RANGES = %w[7 30 90 180 365 all].freeze

  def index
    transactions = current_user_transactions

    uncategorized_count = transactions.uncategorized.count
    flagged_count = transactions.flagged.count
    total_count = transactions.count

    user_anomalies = Anomaly.joins(:bookkeeping_transaction)
                            .where(transactions: { user_id: current_user.id })

    unresolved_count = user_anomalies.unresolved.count
    resolved_count = user_anomalies.where(resolved: true).count

    breakdown = needs_attention_breakdown
    page = [params[:page].to_i, 1].max
    base_scope = build_needs_attention_scope(filter)
    total_for_filter = base_scope.except(:order, :limit, :offset).count
    needs_attention = apply_sort(base_scope).offset((page - 1) * NEEDS_ATTENTION_LIMIT).limit(NEEDS_ATTENTION_LIMIT)

    render json: {
      uncategorized_count: uncategorized_count,
      flagged_anomalies_count: flagged_count,
      total_transactions: total_count,
      unresolved_anomalies_count: unresolved_count,
      resolved_anomalies_count: resolved_count,
      needs_attention: TransactionSerializer.render_as_json(needs_attention, view: :detail),
      needs_attention_breakdown: breakdown,
      needs_attention_page: page,
      needs_attention_total_pages: [(total_for_filter.to_f / NEEDS_ATTENTION_LIMIT).ceil, 1].max,
      needs_attention_total: total_for_filter,
      spending_by_category: spending_by_category,
      spending_category_range: spending_category_range,
      spending_trend: spending_trend,
      spending_trend_range: spending_trend_range,
      spending_trend_granularity: spending_trend_granularity
    }
  end

  private

  def filter
    ALLOWED_FILTERS.include?(params[:filter]) ? params[:filter] : 'all'
  end

  def sort_field
    ALLOWED_SORTS.include?(params[:sort]) ? params[:sort] : 'created_at'
  end

  def sort_direction
    ALLOWED_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'desc'
  end

  def apply_sort(scope)
    dir = sort_direction.to_sym
    if sort_field == 'created_at'
      scope.order(created_at: dir, id: dir)
    else
      # tiebreak by id so order is fully deterministic
      scope.order(sort_field.to_sym => dir, id: dir)
    end
  end

  # Global counts for each filter pill so the UI shows true totals,
  # not just what's in the returned 20.
  def needs_attention_breakdown
    user_id = current_user.id

    user_anomalies = Anomaly.joins(:bookkeeping_transaction)
                            .where(transactions: { user_id: user_id })
                            .unresolved

    uncategorized = current_user_transactions
                      .where(status: 'pending')
                      .where('category IS NULL OR category = ?', '')
                      .count

    # Count DISTINCT transactions with unresolved anomalies, by max severity.
    anomalies_with_severity = user_anomalies
      .select('anomalies.transaction_id, MAX(CASE anomalies.severity ' \
              "WHEN 'high' THEN 3 WHEN 'medium' THEN 2 WHEN 'low' THEN 1 ELSE 0 END) AS max_rank")
      .group('anomalies.transaction_id')

    sev_counts = ActiveRecord::Base.connection.exec_query(
      "SELECT max_rank, COUNT(*) AS c FROM (#{anomalies_with_severity.to_sql}) AS t GROUP BY max_rank"
    ).rows.to_h

    high = sev_counts[3].to_i
    medium = sev_counts[2].to_i
    low = sev_counts[1].to_i + sev_counts[0].to_i  # treat missing/unknown as low

    anomalies_total = high + medium + low

    # "all" = distinct transactions with anomalies OR pending+uncategorized
    all_count = current_user_transactions
      .where(<<~SQL.squish, user_id: user_id)
        transactions.id IN (
          SELECT DISTINCT transactions.id FROM transactions
          LEFT JOIN anomalies ON anomalies.transaction_id = transactions.id
          WHERE transactions.user_id = :user_id
            AND (
              (anomalies.id IS NOT NULL AND anomalies.resolved = false)
              OR (transactions.status = 'pending'
                  AND (transactions.category IS NULL OR transactions.category = ''))
            )
        )
      SQL
      .count

    {
      all: all_count,
      anomalies: anomalies_total,
      high: high,
      medium: medium,
      low: low,
      uncategorized: uncategorized
    }
  end

  # Transactions that need user review, narrowed by filter.
  # Ordered newest-first, capped at NEEDS_ATTENTION_LIMIT.
  def build_needs_attention_scope(filter)
    user_id = current_user.id

    case filter
    when 'uncategorized'
      current_user_transactions
        .where(status: 'pending')
        .where('category IS NULL OR category = ?', '')
        .includes(anomalies: [])
    when 'anomalies', 'high', 'medium', 'low'
      scope = current_user_transactions.where(<<~SQL.squish, user_id: user_id)
        transactions.id IN (
          SELECT DISTINCT anomalies.transaction_id FROM anomalies
          INNER JOIN transactions ON transactions.id = anomalies.transaction_id
          WHERE transactions.user_id = :user_id AND anomalies.resolved = false
        )
      SQL

      if %w[high medium low].include?(filter)
        scope = scope.where(<<~SQL.squish, user_id: user_id, sev: filter)
          transactions.id IN (
            SELECT anomalies.transaction_id FROM anomalies
            INNER JOIN transactions ON transactions.id = anomalies.transaction_id
            WHERE transactions.user_id = :user_id AND anomalies.resolved = false AND anomalies.severity = :sev
          )
        SQL
      end

      scope.includes(anomalies: [])
    else # 'all'
      current_user_transactions
        .where(<<~SQL.squish, user_id: user_id)
          transactions.id IN (
            SELECT DISTINCT transactions.id FROM transactions
            LEFT JOIN anomalies ON anomalies.transaction_id = transactions.id
            WHERE transactions.user_id = :user_id
              AND (
                (anomalies.id IS NOT NULL AND anomalies.resolved = false)
                OR (transactions.status = 'pending'
                    AND (transactions.category IS NULL OR transactions.category = ''))
              )
          )
        SQL
        .includes(anomalies: [])
    end
  end

  # Selected ranges (independent per chart). Falls back to 30 on invalid input.
  def spending_category_range
    raw = params[:spending_category_days].to_s
    ALLOWED_SPENDING_RANGES.include?(raw) ? raw : '30'
  end

  def spending_trend_range
    raw = params[:spending_trend_days].to_s
    ALLOWED_SPENDING_RANGES.include?(raw) ? raw : '30'
  end

  # Whether the trend chart uses daily buckets (short ranges) or monthly
  # (longer ranges). Daily for <=30 days, monthly otherwise.
  def spending_trend_granularity
    days = spending_trend_range
    (days == 'all' || days.to_i > 30) ? 'month' : 'day'
  end

  # Aggregate positive spending grouped by category, within the selected
  # category window. Uncategorized rolls up under "Uncategorized".
  def spending_by_category
    scope = current_user_transactions.where('amount > 0')
    if spending_category_range != 'all'
      scope = scope.where('date >= ?', spending_category_range.to_i.days.ago.to_date)
    end
    scope
      .group(Arel.sql("COALESCE(NULLIF(category, ''), 'Uncategorized')"))
      .sum(:amount)
      .map { |category, total| { category: category, total: total.to_f.round(2) } }
      .sort_by { |row| -row[:total] }
  end

  # Spending trend: daily buckets for short ranges (7/30 days) so the chart
  # actually shows day-to-day variation, monthly for longer ranges so 12
  # months don't squash into 365 tiny bars. Each row: { bucket, total }.
  def spending_trend
    if spending_trend_granularity == 'day'
      n = spending_trend_range.to_i
      start = (n - 1).days.ago.to_date
      raw = current_user_transactions
        .where('date >= ?', start)
        .where('amount > 0')
        .group(:date)
        .sum(:amount)

      (0...n).map do |offset|
        date = start + offset.days
        { bucket: date.strftime('%Y-%m-%d'), total: (raw[date] || 0).to_f.round(2) }
      end
    else
      months = case spending_trend_range
               when '90'  then 3
               when '180' then 6
               when '365' then 12
               else 12
               end

      start = (months - 1).months.ago.beginning_of_month
      raw = current_user_transactions
        .where('date >= ?', start)
        .where('amount > 0')
        .group(Arel.sql("to_char(date, 'YYYY-MM')"))
        .sum(:amount)

      (0...months).map do |offset|
        month_start = start + offset.months
        key = month_start.strftime('%Y-%m')
        { bucket: key, total: (raw[key] || 0).to_f.round(2) }
      end
    end
  end
end
