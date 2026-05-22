require 'rails_helper'

RSpec.describe 'Transactions CRUD', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /api/v1/transactions' do
    it 'returns only the current user transactions' do
      mine = create_list(:transaction, 3, user: user)
      _other = create_list(:transaction, 2, user: create(:user))

      get '/api/v1/transactions'

      ids = JSON.parse(response.body)['transactions'].map { |t| t['id'] }
      expect(ids).to match_array(mine.map(&:id))
    end

    it 'returns an empty array (not an error) when the user has no transactions' do
      get '/api/v1/transactions'

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['transactions']).to eq([])
    end
  end

  describe 'GET /api/v1/transactions/:id' do
    it 'returns the transaction with its anomalies (detail view)' do
      tx = create(:transaction, user: user, description: 'Amazon')
      create(:anomaly, bookkeeping_transaction: tx, anomaly_type: 'unusual_amount')

      get "/api/v1/transactions/#{tx.id}"

      body = JSON.parse(response.body)
      expect(body['id']).to eq(tx.id)
      expect(body['description']).to eq('Amazon')
      expect(body['anomalies'].first['anomaly_type']).to eq('unusual_amount')
    end

    it 'returns 404 when the id belongs to another user (security scoping)' do
      other_tx = create(:transaction, user: create(:user))

      get "/api/v1/transactions/#{other_tx.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/transactions' do
    let(:valid_params) do
      { transaction: { date: '2024-06-15', description: 'Test', amount: '49.99', category: 'Shopping' } }
    end

    it 'creates a transaction scoped to the current user' do
      expect {
        post '/api/v1/transactions', params: valid_params, as: :json
      }.to change(user.transactions, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it 'runs RulesEngine on the new transaction' do
      create(:rule, user: user, priority: 1,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'test' },
        action: { 'type' => 'set_category', 'value' => 'Auto-set' })

      post '/api/v1/transactions',
        params: { transaction: { date: '2024-06-15', description: 'Test', amount: '10' } },
        as: :json

      tx = user.transactions.last
      expect(tx.category).to eq('Auto-set')
    end

    it 'returns 422 with errors when required fields are missing' do
      post '/api/v1/transactions',
        params: { transaction: { description: 'no date or amount' } },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include(match(/date|amount/i))
    end
  end

  describe 'PATCH /api/v1/transactions/:id (non-status update)' do
    it 'updates editable fields' do
      tx = create(:transaction, user: user, description: 'old')

      patch "/api/v1/transactions/#{tx.id}",
        params: { transaction: { description: 'new', category: 'Travel' } },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(tx.reload.description).to eq('new')
      expect(tx.reload.category).to eq('Travel')
    end

    it 'recomputes description_normalized when description changes' do
      tx = create(:transaction, user: user, description: 'Old')

      patch "/api/v1/transactions/#{tx.id}",
        params: { transaction: { description: 'AMAZON MKTP US*2F4KL9' } },
        as: :json

      expect(tx.reload.description_normalized).to eq('amazon mktp us')
    end
  end

  describe 'DELETE /api/v1/transactions/:id' do
    it 'deletes the transaction' do
      tx = create(:transaction, user: user)

      expect {
        delete "/api/v1/transactions/#{tx.id}"
      }.to change(Transaction, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'cascade-deletes the transaction\'s anomalies' do
      tx = create(:transaction, user: user)
      create(:anomaly, bookkeeping_transaction: tx)

      expect {
        delete "/api/v1/transactions/#{tx.id}"
      }.to change(Anomaly, :count).by(-1)
    end
  end
end
