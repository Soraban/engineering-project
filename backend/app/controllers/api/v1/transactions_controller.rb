require 'csv'

class Api::V1::TransactionsController < Api::V1::BaseController
  ALLOWED_SORTS = %w[id date amount].freeze
  ALLOWED_DIRECTIONS = %w[asc desc].freeze

  def index
    scope = filtered_scope
    total = scope.count
    sorted = apply_sort(scope)
    records = sorted.offset((current_page - 1) * page_size).limit(page_size).to_a

    render json: {
      transactions: TransactionSerializer.render_as_json(records),
      page: current_page,
      per_page: page_size,
      total: total,
      total_pages: [(total.to_f / page_size).ceil, 1].max
    }
  end

  EXPORT_HEADERS = %w[id date description amount category status source anomaly_flags].freeze
  EXPORT_BATCH_SIZE = 1000

  def count
    render json: { count: filtered_scope.count }
  end

  def export
    response.headers['Content-Type'] = 'text/csv'
    response.headers['Content-Disposition'] = "attachment; filename=\"transactions-#{Date.current.iso8601}.csv\""
    response.headers['X-Accel-Buffering'] = 'no'
    response.headers.delete('Content-Length')

    self.response_body = Enumerator.new do |yielder|
      yielder << CSV.generate_line(EXPORT_HEADERS)
      each_export_record do |tx|
        yielder << CSV.generate_line(export_row(tx))
      end
    end
  end

  def show
    transaction = current_user_transactions.find(params[:id])
    render json: TransactionSerializer.render_as_json(transaction, view: :detail)
  end

  def create
    transaction = current_user_transactions.build(transaction_params)

    if transaction.save
      RulesEngine.apply(transaction)
      AnomalyDetector.check(transaction)
      render json: TransactionSerializer.render_as_json(transaction.reload, view: :detail), status: :created
    else
      render_error(transaction.errors.full_messages)
    end
  end

  def update
    transaction = current_user_transactions.find(params[:id])

    # The frontend wraps update bodies in { transaction: { ... } }, so the
    # approve flag arrives nested. Accept either shape.
    if params[:approve].present? || params.dig(:transaction, :approve).present?
      approve_and_resolve(transaction)
      render json: TransactionSerializer.render_as_json(transaction.reload, view: :detail)
      return
    end

    new_status = params.dig(:transaction, :status)
    if new_status.present? && new_status != transaction.status
      target = new_status.to_sym
      unless transaction.state_machine.can_transition_to?(target)
        return render_error("Cannot transition from #{transaction.status} to #{new_status}", status: :unprocessable_entity)
      end
      transaction.state_machine.transition_to!(target)
    end

    if transaction.update(transaction_params)
      render json: TransactionSerializer.render_as_json(transaction.reload, view: :detail)
    else
      render_error(transaction.errors.full_messages)
    end
  end

  def destroy
    transaction = current_user_transactions.find(params[:id])
    transaction.destroy!
    head :no_content
  end

  def bulk
    ids = params[:ids] || []
    action = params[:action_type]
    value = params[:value]

    transactions = current_user_transactions.where(id: ids)

    case action
    when 'set_category'
      updated = transactions.update_all(category: value)
    when 'approve'
      updated = 0
      transactions.find_each do |tx|
        if tx.state_machine.can_transition_to?(:reviewed)
          approve_and_resolve(tx)
          updated += 1
        end
      end
    when 'flag'
      updated = 0
      transactions.find_each do |tx|
        if tx.state_machine.can_transition_to?(:flagged)
          tx.state_machine.transition_to!(:flagged)
          updated += 1
        end
      end
    else
      return render_error("Unknown action: #{action}", status: :bad_request)
    end

    render json: { updated_count: updated }
  end

  private

  def transaction_params
    params.require(:transaction).permit(:date, :description, :amount, :category)
  end

  # Approving a transaction also marks any of its open anomalies as resolved.
  # Otherwise the Dashboard's "Needs Attention" (which filters by
  # anomaly.resolved = false) keeps showing flags for a transaction the user
  # has already signed off on.
  def approve_and_resolve(transaction)
    transaction.state_machine.transition_to!(:reviewed)
    transaction.anomalies.where(resolved: false).update_all(
      resolved: true,
      resolved_at: Time.current
    )
  end

  def filtered_scope
    apply_search(apply_filters(current_user_transactions))
  end

  def export_row(tx)
    [
      tx.id,
      tx.date.iso8601,
      tx.description,
      tx.amount.to_s,
      tx.category,
      tx.status,
      tx.source,
      Array(tx.anomaly_flags).join(';')
    ]
  end

  # Streams the filtered scope in date-desc, id-desc order using keyset (cursor)
  # pagination. Unlike find_each, this preserves the requested ORDER BY clause
  # and uses the (user_id, date DESC) index for efficient batching at scale.
  def each_export_record
    last_date = nil
    last_id = nil

    loop do
      batch = filtered_scope
      if last_date
        batch = batch.where(
          '(transactions.date, transactions.id) < (?, ?)',
          last_date, last_id
        )
      end
      records = batch.order(date: :desc, id: :desc).limit(EXPORT_BATCH_SIZE).to_a
      break if records.empty?

      records.each { |tx| yield tx }

      last_date = records.last.date
      last_id = records.last.id
    end
  end

  def apply_filters(scope)
    scope = scope.where(id: params[:id]) if params[:id].present?
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(category: params[:category]) if params[:category].present?
    scope = scope.uncategorized if params[:uncategorized] == 'true'
    if params[:date_from].present?
      scope = scope.where('date >= ?', params[:date_from])
    end
    if params[:date_to].present?
      scope = scope.where('date <= ?', params[:date_to])
    end
    scope
  end

  def apply_search(scope)
    return scope unless params[:search].present?
    scope.search_description(params[:search])
  end

  def sort_field
    ALLOWED_SORTS.include?(params[:sort]) ? params[:sort] : 'id'
  end

  def sort_direction
    ALLOWED_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'desc'
  end

  # When sorting by date, the natural secondary tiebreaker is amount, and
  # vice versa. id is always the final tiebreaker for full determinism.
  def secondary_field
    sort_field == 'date' ? 'amount' : 'date'
  end

  def apply_sort(scope)
    dir = sort_direction.to_sym
    if sort_field == 'id'
      scope.order(id: dir)
    else
      scope.order(sort_field.to_sym => dir, secondary_field.to_sym => dir, id: dir)
    end
  end

  def current_page
    [params[:page].to_i, 1].max
  end

  def page_size
    [(params[:per_page] || 50).to_i, 100].min
  end
end
