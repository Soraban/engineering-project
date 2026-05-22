require 'rails_helper'

RSpec.describe 'PATCH /api/v1/transactions/:id (status changes via state machine)', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it 'allows reviewed -> pending (the "undo accidental approval" case)' do
    tx = create(:transaction, user: user, status: 'pending')
    tx.state_machine.transition_to!(:reviewed)
    expect(tx.reload.status).to eq('reviewed')

    patch "/api/v1/transactions/#{tx.id}", params: { transaction: { status: 'pending' } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(tx.reload.status).to eq('pending')
  end

  it 'still records every transition on the audit trail when status changes via edit' do
    tx = create(:transaction, user: user)
    tx.state_machine.transition_to!(:reviewed)

    patch "/api/v1/transactions/#{tx.id}", params: { transaction: { status: 'pending' } }, as: :json

    expect(tx.transaction_transitions.count).to eq(2) # pending->reviewed, then reviewed->pending
    expect(tx.transaction_transitions.last.to_state).to eq('pending')
  end

  it 'allows reviewed -> flagged' do
    tx = create(:transaction, user: user)
    tx.state_machine.transition_to!(:reviewed)

    patch "/api/v1/transactions/#{tx.id}", params: { transaction: { status: 'flagged' } }, as: :json

    expect(tx.reload.status).to eq('flagged')
  end

  it 'returns an error for impossible transitions instead of silently writing the column' do
    tx = create(:transaction, user: user, status: 'pending')
    # pending -> pending is a no-op, not allowed
    patch "/api/v1/transactions/#{tx.id}", params: { transaction: { status: 'something_invalid' } }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'updates other fields alongside the status change' do
    tx = create(:transaction, user: user, status: 'pending', description: 'old')

    patch "/api/v1/transactions/#{tx.id}",
      params: { transaction: { status: 'reviewed', description: 'new' } },
      as: :json

    tx.reload
    expect(tx.status).to eq('reviewed')
    expect(tx.description).to eq('new')
  end
end
