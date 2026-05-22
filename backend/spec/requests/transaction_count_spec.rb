require 'rails_helper'

RSpec.describe 'GET /api/v1/transactions/count', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it 'returns the total count of the current user transactions' do
    create_list(:transaction, 7, user: user)

    get '/api/v1/transactions/count'

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq('count' => 7)
  end

  it "excludes other users' transactions" do
    create_list(:transaction, 3, user: user)
    create_list(:transaction, 5, user: create(:user))

    get '/api/v1/transactions/count'

    expect(JSON.parse(response.body)['count']).to eq(3)
  end

  it 'respects the status filter' do
    create_list(:transaction, 2, user: user, status: 'pending')
    create_list(:transaction, 3, user: user, status: 'flagged')

    get '/api/v1/transactions/count', params: { status: 'flagged' }

    expect(JSON.parse(response.body)['count']).to eq(3)
  end

  it 'respects the date range filter' do
    create(:transaction, user: user, date: Date.new(2024, 1, 1))
    create(:transaction, user: user, date: Date.new(2024, 6, 15))
    create(:transaction, user: user, date: Date.new(2024, 12, 1))

    get '/api/v1/transactions/count', params: { date_from: '2024-06-01', date_to: '2024-08-31' }

    expect(JSON.parse(response.body)['count']).to eq(1)
  end

  it 'returns 0 when no transactions match' do
    get '/api/v1/transactions/count', params: { status: 'reviewed' }

    expect(JSON.parse(response.body)['count']).to eq(0)
  end
end
