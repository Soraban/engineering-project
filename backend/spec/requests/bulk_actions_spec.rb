require 'rails_helper'

RSpec.describe 'PUT /api/v1/transactions/bulk', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it 'categorizes multiple transactions in one request' do
    txs = create_list(:transaction, 5, user: user, category: nil)

    put '/api/v1/transactions/bulk',
      params: { ids: txs.map(&:id), action_type: 'set_category', value: 'Travel' },
      as: :json

    expect(response).to have_http_status(:ok)
    expect(json_body['updated_count']).to eq(5)
    txs.each { |t| expect(t.reload.category).to eq('Travel') }
  end

  it 'rejects bulk action on transactions belonging to another user' do
    other_user = create(:user)
    txs = create_list(:transaction, 3, user: other_user)

    put '/api/v1/transactions/bulk',
      params: { ids: txs.map(&:id), action_type: 'set_category', value: 'Travel' },
      as: :json

    expect(response).to have_http_status(:ok)
    expect(json_body['updated_count']).to eq(0)
  end

  it 'returns error for unknown action type' do
    txs = create_list(:transaction, 2, user: user)

    put '/api/v1/transactions/bulk',
      params: { ids: txs.map(&:id), action_type: 'invalid' },
      as: :json

    expect(response).to have_http_status(:bad_request)
  end
end
