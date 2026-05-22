require 'rails_helper'

RSpec.describe 'GET /api/v1/dashboard (needs_attention)', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  def needs_attention_ids
    JSON.parse(response.body)['needs_attention'].map { |t| t['id'] }
  end

  it 'includes transactions with at least one unresolved anomaly' do
    with_anomaly = create(:transaction, user: user)
    create(:anomaly, bookkeeping_transaction: with_anomaly, resolved: false)

    get '/api/v1/dashboard'

    expect(needs_attention_ids).to include(with_anomaly.id)
  end

  it 'includes pending uncategorized transactions even when they have no anomalies' do
    uncat = create(:transaction, user: user, status: 'pending', category: nil)

    get '/api/v1/dashboard'

    expect(needs_attention_ids).to include(uncat.id)
  end

  it 'excludes transactions whose anomalies are all resolved and which have a category' do
    done = create(:transaction, user: user, status: 'reviewed', category: 'Shopping')
    create(:anomaly, bookkeeping_transaction: done, resolved: true, resolved_at: 1.hour.ago)

    get '/api/v1/dashboard'

    expect(needs_attention_ids).not_to include(done.id)
  end

  it 'excludes reviewed-but-still-uncategorized transactions (they were intentionally signed off)' do
    reviewed_no_cat = create(:transaction, user: user, status: 'reviewed', category: nil)

    get '/api/v1/dashboard'

    expect(needs_attention_ids).not_to include(reviewed_no_cat.id)
  end

  it 'serializes anomalies inline on each transaction (for severity + type display)' do
    tx = create(:transaction, user: user, amount: 8500)
    create(:anomaly, bookkeeping_transaction: tx, anomaly_type: 'unusual_amount', severity: 'high', resolved: false)
    create(:anomaly, bookkeeping_transaction: tx, anomaly_type: 'missing_metadata', severity: 'low', resolved: false)

    get '/api/v1/dashboard'

    row = JSON.parse(response.body)['needs_attention'].find { |t| t['id'] == tx.id }
    expect(row['amount'].to_f).to eq(8500.0)
    types = row['anomalies'].map { |a| a['anomaly_type'] }
    expect(types).to match_array(%w[unusual_amount missing_metadata])
  end

  it 'does not duplicate a transaction that has multiple unresolved anomalies' do
    tx = create(:transaction, user: user)
    create_list(:anomaly, 3, bookkeeping_transaction: tx, resolved: false)

    get '/api/v1/dashboard'

    expect(needs_attention_ids.count(tx.id)).to eq(1)
  end

  it 'returns at most NEEDS_ATTENTION_LIMIT rows' do
    create_list(:transaction, 25, user: user, status: 'pending', category: nil)

    get '/api/v1/dashboard'

    expect(needs_attention_ids.length).to eq(Api::V1::DashboardController::NEEDS_ATTENTION_LIMIT)
  end

  it 'returns both unresolved and resolved anomaly counts' do
    tx = create(:transaction, user: user)
    create_list(:anomaly, 2, bookkeeping_transaction: tx, resolved: false)
    create_list(:anomaly, 3, bookkeeping_transaction: tx, resolved: true)

    get '/api/v1/dashboard'

    body = JSON.parse(response.body)
    expect(body['unresolved_anomalies_count']).to eq(2)
    expect(body['resolved_anomalies_count']).to eq(3)
  end

  describe 'filter param' do
    it 'returns only transactions with unresolved anomalies when filter=anomalies' do
      with_anomaly = create(:transaction, user: user, category: 'Shopping')
      create(:anomaly, bookkeeping_transaction: with_anomaly, resolved: false)
      _just_uncat = create(:transaction, user: user, status: 'pending', category: nil)

      get '/api/v1/dashboard', params: { filter: 'anomalies' }

      expect(needs_attention_ids).to eq([with_anomaly.id])
    end

    it 'returns only pending+uncategorized when filter=uncategorized' do
      _with_anomaly = create(:transaction, user: user, category: 'Shopping').tap do |t|
        create(:anomaly, bookkeeping_transaction: t, resolved: false)
      end
      uncat = create(:transaction, user: user, status: 'pending', category: nil)

      get '/api/v1/dashboard', params: { filter: 'uncategorized' }

      expect(needs_attention_ids).to eq([uncat.id])
    end

    it 'filters by severity when filter=high' do
      high_tx = create(:transaction, user: user)
      create(:anomaly, bookkeeping_transaction: high_tx, severity: 'high', resolved: false)

      med_tx = create(:transaction, user: user)
      create(:anomaly, bookkeeping_transaction: med_tx, severity: 'medium', resolved: false)

      get '/api/v1/dashboard', params: { filter: 'high' }

      expect(needs_attention_ids).to eq([high_tx.id])
    end

    it 'falls back to all when filter is unknown' do
      tx = create(:transaction, user: user, status: 'pending', category: nil)

      get '/api/v1/dashboard', params: { filter: 'gibberish' }

      expect(needs_attention_ids).to include(tx.id)
    end
  end

  describe 'sort param' do
    it 'sorts by date desc by default when sort=date' do
      old = create(:transaction, user: user, status: 'pending', category: nil, date: Date.new(2024, 1, 1))
      mid = create(:transaction, user: user, status: 'pending', category: nil, date: Date.new(2024, 6, 1))
      new = create(:transaction, user: user, status: 'pending', category: nil, date: Date.new(2024, 12, 1))

      get '/api/v1/dashboard', params: { sort: 'date', direction: 'desc' }

      expect(needs_attention_ids).to eq([new.id, mid.id, old.id])
    end

    it 'sorts by date asc when direction=asc' do
      old = create(:transaction, user: user, status: 'pending', category: nil, date: Date.new(2024, 1, 1))
      new = create(:transaction, user: user, status: 'pending', category: nil, date: Date.new(2024, 12, 1))

      get '/api/v1/dashboard', params: { sort: 'date', direction: 'asc' }

      expect(needs_attention_ids).to eq([old.id, new.id])
    end

    it 'falls back to created_at when sort param is unknown' do
      create(:transaction, user: user, status: 'pending', category: nil)
      get '/api/v1/dashboard', params: { sort: 'gibberish' }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'pagination' do
    before do
      # 25 needs-attention transactions, paginated 20 per page
      create_list(:transaction, 25, user: user, status: 'pending', category: nil)
    end

    it 'returns the first page by default' do
      get '/api/v1/dashboard'

      body = JSON.parse(response.body)
      expect(body['needs_attention'].length).to eq(20)
      expect(body['needs_attention_page']).to eq(1)
      expect(body['needs_attention_total_pages']).to eq(2)
      expect(body['needs_attention_total']).to eq(25)
    end

    it 'returns the second page when page=2' do
      get '/api/v1/dashboard', params: { page: 2 }

      body = JSON.parse(response.body)
      expect(body['needs_attention'].length).to eq(5)
      expect(body['needs_attention_page']).to eq(2)
    end

    it 'clamps invalid page values to page 1' do
      get '/api/v1/dashboard', params: { page: -5 }

      body = JSON.parse(response.body)
      expect(body['needs_attention_page']).to eq(1)
    end
  end

  describe 'spending range params (independent for category vs trend)' do
    before do
      create(:transaction, user: user, date: 200.days.ago.to_date, amount: 100)
      create(:transaction, user: user, date: 3.days.ago.to_date, amount: 50)
      create(:transaction, user: user, date: 5.days.ago.to_date, amount: 25)
    end

    it 'defaults to 30 days for both ranges' do
      get '/api/v1/dashboard'

      body = JSON.parse(response.body)
      expect(body['spending_category_range']).to eq('30')
      expect(body['spending_trend_range']).to eq('30')
    end

    it 'category range and trend range are independent' do
      get '/api/v1/dashboard', params: { spending_category_days: '365', spending_trend_days: '90' }

      body = JSON.parse(response.body)
      expect(body['spending_category_range']).to eq('365')
      expect(body['spending_trend_range']).to eq('90')
    end

    it 'category aggregation respects the category range only' do
      get '/api/v1/dashboard', params: { spending_category_days: '7', spending_trend_days: '365' }

      total = JSON.parse(response.body)['spending_by_category'].sum { |r| r['total'] }
      expect(total).to eq(75.0) # only the two recent (3d, 5d) transactions
    end

    it 'accepts the new 7d option' do
      get '/api/v1/dashboard', params: { spending_category_days: '7' }
      expect(JSON.parse(response.body)['spending_category_range']).to eq('7')
    end

    it 'falls back to 30 on invalid values for either range' do
      get '/api/v1/dashboard', params: { spending_category_days: 'forever', spending_trend_days: 'never' }

      body = JSON.parse(response.body)
      expect(body['spending_category_range']).to eq('30')
      expect(body['spending_trend_range']).to eq('30')
    end

    it 'uses DAILY granularity for trend ranges <= 30 days' do
      get '/api/v1/dashboard', params: { spending_trend_days: '7' }

      body = JSON.parse(response.body)
      expect(body['spending_trend_granularity']).to eq('day')
      expect(body['spending_trend'].size).to eq(7)
      expect(body['spending_trend'].first['bucket']).to match(/^\d{4}-\d{2}-\d{2}$/)
    end

    it 'uses MONTHLY granularity for trend ranges > 30 days' do
      get '/api/v1/dashboard', params: { spending_trend_days: '90' }

      body = JSON.parse(response.body)
      expect(body['spending_trend_granularity']).to eq('month')
      expect(body['spending_trend'].size).to eq(3)
      expect(body['spending_trend'].first['bucket']).to match(/^\d{4}-\d{2}$/)
    end
  end

  describe 'needs_attention_breakdown global counts' do
    it 'returns accurate counts per filter, even when the loaded list is smaller' do
      # 25 uncategorized (NEEDS_ATTENTION_LIMIT is 20, so list will only show 20)
      create_list(:transaction, 25, user: user, status: 'pending', category: nil)

      # 2 high, 1 medium, 1 low anomaly transactions
      2.times do
        tx = create(:transaction, user: user, category: 'Shopping')
        create(:anomaly, bookkeeping_transaction: tx, severity: 'high', resolved: false)
      end
      tx = create(:transaction, user: user, category: 'Shopping')
      create(:anomaly, bookkeeping_transaction: tx, severity: 'medium', resolved: false)
      tx = create(:transaction, user: user, category: 'Shopping')
      create(:anomaly, bookkeeping_transaction: tx, severity: 'low', resolved: false)

      get '/api/v1/dashboard'

      breakdown = JSON.parse(response.body)['needs_attention_breakdown']
      expect(breakdown['uncategorized']).to eq(25)
      expect(breakdown['high']).to eq(2)
      expect(breakdown['medium']).to eq(1)
      expect(breakdown['low']).to eq(1)
      expect(breakdown['anomalies']).to eq(4)
      expect(breakdown['all']).to eq(29) # 25 uncat + 4 anomaly transactions
    end
  end
end
