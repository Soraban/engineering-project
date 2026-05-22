require 'rails_helper'

RSpec.describe 'Approving a transaction auto-resolves its open anomalies', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'PATCH /api/v1/transactions/:id with approve=true' do
    it 'transitions the transaction to reviewed AND resolves all unresolved anomalies on it' do
      tx = create(:transaction, user: user, status: 'flagged')
      a1 = create(:anomaly, bookkeeping_transaction: tx, anomaly_type: 'unusual_amount', resolved: false)
      a2 = create(:anomaly, bookkeeping_transaction: tx, anomaly_type: 'missing_metadata', resolved: false)

      patch "/api/v1/transactions/#{tx.id}", params: { approve: true }, as: :json

      expect(response).to have_http_status(:ok)
      expect(tx.reload.status).to eq('reviewed')
      expect(a1.reload).to be_resolved
      expect(a2.reload).to be_resolved
      expect(a1.resolved_at).to be_present
    end

    it 'does not re-resolve anomalies that were already resolved (leaves resolved_at alone)' do
      tx = create(:transaction, user: user, status: 'flagged')
      original_time = 1.day.ago
      a = create(:anomaly, bookkeeping_transaction: tx, resolved: true, resolved_at: original_time)

      patch "/api/v1/transactions/#{tx.id}", params: { approve: true }, as: :json

      expect(a.reload.resolved_at).to be_within(1.second).of(original_time)
    end

    it 'also works when approve is nested under transaction (frontend payload shape)' do
      tx = create(:transaction, user: user, status: 'flagged')
      a = create(:anomaly, bookkeeping_transaction: tx, resolved: false)

      # This is how the frontend's updateTransaction(id, { approve: true }) actually sends it
      patch "/api/v1/transactions/#{tx.id}", params: { transaction: { approve: true } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(tx.reload.status).to eq('reviewed')
      expect(a.reload).to be_resolved
    end
  end

  describe 'PUT /api/v1/transactions/bulk with action_type=approve' do
    it 'resolves anomalies for every approved transaction' do
      txs = create_list(:transaction, 3, user: user, status: 'flagged')
      anomalies = txs.map { |tx| create(:anomaly, bookkeeping_transaction: tx, resolved: false) }

      put '/api/v1/transactions/bulk',
        params: { ids: txs.map(&:id), action_type: 'approve' },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['updated_count']).to eq(3)
      txs.each { |tx| expect(tx.reload.status).to eq('reviewed') }
      anomalies.each { |a| expect(a.reload).to be_resolved }
    end
  end
end
