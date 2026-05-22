require 'rails_helper'

RSpec.describe 'GET /api/v1/transactions (sorting)', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  def ids_in_order
    JSON.parse(response.body)['transactions'].map { |t| t['id'] }
  end


  describe 'sort=date' do
    let!(:oldest) { create(:transaction, user: user, date: Date.new(2024, 1, 1)) }
    let!(:middle) { create(:transaction, user: user, date: Date.new(2024, 6, 15)) }
    let!(:newest) { create(:transaction, user: user, date: Date.new(2024, 12, 31)) }

    it 'returns rows newest-first when direction=desc' do
      get '/api/v1/transactions', params: { sort: 'date', direction: 'desc' }
      expect(ids_in_order).to eq([newest.id, middle.id, oldest.id])
    end

    it 'returns rows oldest-first when direction=asc' do
      get '/api/v1/transactions', params: { sort: 'date', direction: 'asc' }
      expect(ids_in_order).to eq([oldest.id, middle.id, newest.id])
    end
  end

  describe 'sort=amount' do
    let!(:cheap)     { create(:transaction, user: user, amount: 5.00) }
    let!(:moderate)  { create(:transaction, user: user, amount: 75.00) }
    let!(:expensive) { create(:transaction, user: user, amount: 999.00) }

    it 'returns rows highest-first when direction=desc' do
      get '/api/v1/transactions', params: { sort: 'amount', direction: 'desc' }
      expect(ids_in_order).to eq([expensive.id, moderate.id, cheap.id])
    end

    it 'returns rows lowest-first when direction=asc' do
      get '/api/v1/transactions', params: { sort: 'amount', direction: 'asc' }
      expect(ids_in_order).to eq([cheap.id, moderate.id, expensive.id])
    end
  end

  describe 'sort=id (default)' do
    it 'defaults to id desc when no sort param is given' do
      txs = create_list(:transaction, 3, user: user)
      get '/api/v1/transactions'
      expect(ids_in_order).to eq(txs.map(&:id).reverse)
    end
  end

  describe 'param validation' do
    let!(:txs) { create_list(:transaction, 2, user: user) }

    it 'falls back to id when sort param is not in the allowlist' do
      get '/api/v1/transactions', params: { sort: 'description' }
      expect(response).to have_http_status(:ok)
      expect(ids_in_order).to eq(txs.map(&:id).reverse)
    end

    it 'falls back to desc when direction param is not in the allowlist' do
      get '/api/v1/transactions', params: { direction: 'sideways' }
      expect(response).to have_http_status(:ok)
      expect(ids_in_order).to eq(txs.map(&:id).reverse)
    end
  end

  describe 'cursor format' do
    it 'returns page metadata in the response' do
      create_list(:transaction, 3, user: user)
      get '/api/v1/transactions', params: { sort: 'id', per_page: 2 }

      body = JSON.parse(response.body)
      expect(body['page']).to eq(1)
      expect(body['per_page']).to eq(2)
      expect(body['total']).to eq(3)
      expect(body['total_pages']).to eq(2)
    end

    it 'returns the requested page when page= is provided' do
      txs = create_list(:transaction, 5, user: user) # id-desc: txs[4], txs[3], txs[2], txs[1], txs[0]

      get '/api/v1/transactions', params: { sort: 'id', direction: 'desc', per_page: 2, page: 2 }

      expect(ids_in_order).to eq([txs[2].id, txs[1].id])
    end

    it 'clamps page values less than 1 to 1' do
      create_list(:transaction, 2, user: user)

      get '/api/v1/transactions', params: { page: -5 }

      expect(JSON.parse(response.body)['page']).to eq(1)
    end
  end

  describe 'secondary tiebreaker behavior' do
    it 'breaks amount ties by date in the same direction (sort=amount desc)' do
      same_amount = 50.00
      older = create(:transaction, user: user, amount: same_amount, date: Date.new(2024, 1, 1))
      newer = create(:transaction, user: user, amount: same_amount, date: Date.new(2024, 6, 1))

      get '/api/v1/transactions', params: { sort: 'amount', direction: 'desc' }

      # Within the $50.00 tie, the newer date should come first when desc
      expect(ids_in_order).to eq([newer.id, older.id])
    end

    it 'breaks amount ties by date in the same direction (sort=amount asc)' do
      same_amount = 50.00
      older = create(:transaction, user: user, amount: same_amount, date: Date.new(2024, 1, 1))
      newer = create(:transaction, user: user, amount: same_amount, date: Date.new(2024, 6, 1))

      get '/api/v1/transactions', params: { sort: 'amount', direction: 'asc' }

      # Within the $50.00 tie, the older date should come first when asc
      expect(ids_in_order).to eq([older.id, newer.id])
    end

    it 'breaks date ties by amount in the same direction (sort=date desc)' do
      same_date = Date.new(2024, 6, 1)
      cheap = create(:transaction, user: user, date: same_date, amount: 10.00)
      pricey = create(:transaction, user: user, date: same_date, amount: 500.00)

      get '/api/v1/transactions', params: { sort: 'date', direction: 'desc' }

      # Within the same-date tie, the higher amount should come first when desc
      expect(ids_in_order).to eq([pricey.id, cheap.id])
    end
  end
end
