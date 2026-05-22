require 'rails_helper'

RSpec.describe Transaction, type: :model do
  let(:user) { create(:user) }

  describe '.normalize_description' do
    it 'returns nil for blank input' do
      expect(Transaction.normalize_description(nil)).to be_nil
      expect(Transaction.normalize_description('')).to be_nil
      expect(Transaction.normalize_description('   ')).to be_nil
    end

    it 'downcases the string' do
      expect(Transaction.normalize_description('AMAZON Purchase')).to eq('amazon purchase')
    end

    it 'strips trailing reference codes like *2F4KL9' do
      expect(Transaction.normalize_description('AMAZON MKTP US*2F4KL9')).to eq('amazon mktp us')
      expect(Transaction.normalize_description('AMAZON MKTP US*8B2MQ1')).to eq('amazon mktp us')
    end

    it 'strips location/store codes like #1204' do
      expect(Transaction.normalize_description('Starbucks #1204')).to eq('starbucks')
      expect(Transaction.normalize_description('Starbucks #9881')).to eq('starbucks')
    end

    it 'collapses multiple spaces into one' do
      expect(Transaction.normalize_description('Whole   Foods    Market')).to eq('whole foods market')
    end

    it 'strips leading and trailing whitespace' do
      expect(Transaction.normalize_description('  Netflix  ')).to eq('netflix')
    end

    it 'normalizes "AMAZON MKTP US*2F4KL9" and "AMAZON MKTP US*8B2MQ1" to the same value (duplicate detection key)' do
      a = Transaction.normalize_description('AMAZON MKTP US*2F4KL9')
      b = Transaction.normalize_description('AMAZON MKTP US*8B2MQ1')
      expect(a).to eq(b)
    end
  end

  describe 'before_save callback' do
    it 'auto-computes description_normalized when description is set' do
      tx = create(:transaction, user: user, description: 'Starbucks #1204')
      expect(tx.description_normalized).to eq('starbucks')
    end

    it 'recomputes description_normalized when description changes' do
      tx = create(:transaction, user: user, description: 'Amazon')
      tx.update!(description: 'AMAZON MKTP US*ZZZZ')
      expect(tx.description_normalized).to eq('amazon mktp us')
    end

    it 'sets description_normalized to nil when description is blank' do
      tx = create(:transaction, user: user, description: nil)
      expect(tx.description_normalized).to be_nil
    end
  end

  describe 'validations' do
    it 'requires a date' do
      tx = Transaction.new(user: user, amount: 10, date: nil)
      expect(tx).not_to be_valid
      expect(tx.errors[:date]).to include("can't be blank")
    end

    it 'requires an amount' do
      tx = Transaction.new(user: user, date: Date.today, amount: nil)
      expect(tx).not_to be_valid
      expect(tx.errors[:amount]).to include("can't be blank")
    end

    it 'requires amount to be numeric' do
      tx = Transaction.new(user: user, date: Date.today, amount: 'not-a-number')
      expect(tx).not_to be_valid
    end

    it 'accepts decimal amounts' do
      tx = Transaction.new(user: user, date: Date.today, amount: 49.99)
      expect(tx).to be_valid
    end

    it 'accepts negative amounts (refunds)' do
      tx = Transaction.new(user: user, date: Date.today, amount: -25.00)
      expect(tx).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a user' do
      tx = create(:transaction, user: user)
      expect(tx.user).to eq(user)
    end

    it 'has many anomalies' do
      tx = create(:transaction, user: user)
      a1 = create(:anomaly, bookkeeping_transaction: tx)
      a2 = create(:anomaly, bookkeeping_transaction: tx)
      expect(tx.anomalies).to contain_exactly(a1, a2)
    end

    it 'cascades deletes to anomalies' do
      tx = create(:transaction, user: user)
      create(:anomaly, bookkeeping_transaction: tx)
      expect { tx.destroy }.to change(Anomaly, :count).by(-1)
    end
  end

  describe 'state machine' do
    let(:tx) { create(:transaction, user: user) }

    it 'starts in pending state' do
      expect(tx.status).to eq('pending')
    end

    it 'allows pending -> reviewed' do
      tx.state_machine.transition_to!(:reviewed)
      expect(tx.reload.status).to eq('reviewed')
    end

    it 'allows pending -> flagged' do
      tx.state_machine.transition_to!(:flagged)
      expect(tx.reload.status).to eq('flagged')
    end

    it 'allows flagged -> reviewed' do
      tx.state_machine.transition_to!(:flagged)
      tx.state_machine.transition_to!(:reviewed)
      expect(tx.reload.status).to eq('reviewed')
    end

    it 'allows flagged -> pending (dismiss flag)' do
      tx.state_machine.transition_to!(:flagged)
      tx.state_machine.transition_to!(:pending)
      expect(tx.reload.status).to eq('pending')
    end

    it 'allows reviewed -> pending (undo accidental approval)' do
      tx.state_machine.transition_to!(:reviewed)
      tx.state_machine.transition_to!(:pending)
      expect(tx.reload.status).to eq('pending')
    end

    it 'persists every transition for the audit trail' do
      tx.state_machine.transition_to!(:reviewed)
      tx.state_machine.transition_to!(:pending)
      tx.state_machine.transition_to!(:flagged)

      states = tx.transaction_transitions.order(:sort_key).pluck(:to_state)
      expect(states).to eq(%w[reviewed pending flagged])
    end
  end

  describe 'scopes' do
    it 'flagged returns only flagged status' do
      flagged = create(:transaction, user: user, status: 'flagged')
      create(:transaction, user: user, status: 'pending')
      expect(Transaction.flagged).to contain_exactly(flagged)
    end

    it 'pending returns only pending status' do
      pending = create(:transaction, user: user, status: 'pending')
      create(:transaction, user: user, status: 'reviewed')
      expect(Transaction.pending).to contain_exactly(pending)
    end

    it 'uncategorized returns rows with nil or empty category' do
      uncat_nil = create(:transaction, user: user, category: nil)
      uncat_empty = create(:transaction, user: user, category: '')
      create(:transaction, user: user, category: 'Shopping')

      expect(Transaction.uncategorized).to contain_exactly(uncat_nil, uncat_empty)
    end
  end
end
