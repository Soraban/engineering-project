require 'rails_helper'

RSpec.describe 'GET /api/v1/transactions (id filter)', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  def ids
    JSON.parse(response.body)['transactions'].map { |t| t['id'] }
  end

  it 'returns only the requested transaction when id param is given' do
    txs = create_list(:transaction, 3, user: user)

    get '/api/v1/transactions', params: { id: txs[1].id }

    expect(ids).to eq([txs[1].id])
  end

  it 'returns no rows when the id belongs to another user (security scoping)' do
    create(:transaction, user: user)
    other = create(:transaction, user: create(:user))

    get '/api/v1/transactions', params: { id: other.id }

    expect(ids).to be_empty
  end

  it 'ignores the id param when it is blank' do
    txs = create_list(:transaction, 3, user: user)

    get '/api/v1/transactions', params: { id: '' }

    expect(ids).to match_array(txs.map(&:id))
  end
end
