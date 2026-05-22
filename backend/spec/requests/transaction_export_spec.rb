require 'rails_helper'
require 'csv'

RSpec.describe 'GET /api/v1/transactions/export', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  def csv_rows
    CSV.parse(response.body, headers: true)
  end

  it 'returns a CSV with the expected headers' do
    create(:transaction, user: user)
    get '/api/v1/transactions/export'

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to start_with('text/csv')
    expect(csv_rows.headers).to eq(%w[id date description amount category status source anomaly_flags])
  end

  it 'includes a Content-Disposition attachment header with a dated filename' do
    create(:transaction, user: user)
    get '/api/v1/transactions/export'

    expect(response.headers['Content-Disposition']).to include('attachment')
    expect(response.headers['Content-Disposition']).to match(/transactions-\d{4}-\d{2}-\d{2}\.csv/)
  end

  it "only includes the current user's transactions" do
    mine    = create(:transaction, user: user, description: 'Mine')
    other   = create(:transaction, user: create(:user), description: 'Other')

    get '/api/v1/transactions/export'

    ids = csv_rows.map { |r| r['id'].to_i }
    expect(ids).to include(mine.id)
    expect(ids).not_to include(other.id)
  end

  it 'returns only headers when no transactions match' do
    get '/api/v1/transactions/export'

    expect(csv_rows.size).to eq(0)
    expect(response.body.lines.first.strip).to eq('id,date,description,amount,category,status,source,anomaly_flags')
  end

  it 'respects the status filter' do
    pending_tx = create(:transaction, user: user, status: 'pending')
    create(:transaction, user: user, status: 'reviewed')

    get '/api/v1/transactions/export', params: { status: 'pending' }

    ids = csv_rows.map { |r| r['id'].to_i }
    expect(ids).to eq([pending_tx.id])
  end

  it 'respects the category filter' do
    travel = create(:transaction, user: user, category: 'Travel')
    create(:transaction, user: user, category: 'Food')

    get '/api/v1/transactions/export', params: { category: 'Travel' }

    ids = csv_rows.map { |r| r['id'].to_i }
    expect(ids).to eq([travel.id])
  end

  it 'respects the date range filter' do
    in_range  = create(:transaction, user: user, date: Date.new(2024, 6, 15))
    create(:transaction, user: user, date: Date.new(2024, 1, 1))

    get '/api/v1/transactions/export', params: { date_from: '2024-06-01', date_to: '2024-06-30' }

    ids = csv_rows.map { |r| r['id'].to_i }
    expect(ids).to eq([in_range.id])
  end

  it 'properly escapes descriptions containing commas and quotes' do
    create(:transaction, user: user, description: 'Whole Foods, "San Francisco"')

    get '/api/v1/transactions/export'

    parsed_row = csv_rows.first
    expect(parsed_row['description']).to eq('Whole Foods, "San Francisco"')
  end

  it 'serializes anomaly_flags as a semicolon-separated string' do
    create(:transaction, user: user, anomaly_flags: %w[unusual_amount missing_metadata])

    get '/api/v1/transactions/export'

    expect(csv_rows.first['anomaly_flags']).to eq('unusual_amount;missing_metadata')
  end

  it 'opts out of proxy buffering so the response streams as it is generated' do
    create_list(:transaction, 3, user: user)

    get '/api/v1/transactions/export'

    expect(response.headers['X-Accel-Buffering']).to eq('no')
  end

  it 'produces the same correct output regardless of row count (proves the enumerator builds the body)' do
    create_list(:transaction, 25, user: user)

    get '/api/v1/transactions/export'

    expect(csv_rows.size).to eq(25)
    expect(response.body.lines.first.strip).to eq('id,date,description,amount,category,status,source,anomaly_flags')
  end

  it 'returns rows in date DESC, id DESC order' do
    older  = create(:transaction, user: user, date: Date.new(2024, 1, 1))
    newer  = create(:transaction, user: user, date: Date.new(2024, 6, 1))
    newest = create(:transaction, user: user, date: Date.new(2024, 6, 1)) # same date, higher id

    get '/api/v1/transactions/export'

    ids_in_order = csv_rows.map { |r| r['id'].to_i }
    expect(ids_in_order).to eq([newest.id, newer.id, older.id])
  end

  it 'preserves order across batch boundaries (keyset pagination correctness)' do
    # Force multiple batches with a tiny batch size, then verify ordering is
    # correct globally — not just within a single batch.
    stub_const('Api::V1::TransactionsController::EXPORT_BATCH_SIZE', 3)

    # Create 10 transactions spanning 10 different dates
    txs = 10.times.map { |i| create(:transaction, user: user, date: Date.new(2024, 1, 1) + i.days) }

    get '/api/v1/transactions/export'

    expected_ids_in_date_desc = txs.sort_by(&:date).reverse.map(&:id)
    actual_ids                = csv_rows.map { |r| r['id'].to_i }
    expect(actual_ids).to eq(expected_ids_in_date_desc)
  end

  it 'preserves order across batch boundaries when ties on date are broken by id DESC' do
    stub_const('Api::V1::TransactionsController::EXPORT_BATCH_SIZE', 2)

    # All on the same date — tiebreaker is id DESC
    txs = create_list(:transaction, 5, user: user, date: Date.new(2024, 6, 1))

    get '/api/v1/transactions/export'

    actual_ids = csv_rows.map { |r| r['id'].to_i }
    expect(actual_ids).to eq(txs.map(&:id).sort.reverse)
  end
end
