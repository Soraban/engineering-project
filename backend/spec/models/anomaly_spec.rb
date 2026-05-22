require 'rails_helper'

RSpec.describe Anomaly, type: :model do
  let(:user) { create(:user) }
  let(:tx)   { create(:transaction, user: user) }

  describe 'associations' do
    it 'belongs to a bookkeeping_transaction (aliased from :transaction to avoid Rails reserved word)' do
      anomaly = create(:anomaly, bookkeeping_transaction: tx)
      expect(anomaly.bookkeeping_transaction).to eq(tx)
    end

    it 'is destroyed when the parent transaction is destroyed' do
      create(:anomaly, bookkeeping_transaction: tx)
      expect { tx.destroy }.to change(Anomaly, :count).by(-1)
    end
  end

  describe 'unresolved scope' do
    it 'returns only anomalies where resolved is false' do
      open = create(:anomaly, bookkeeping_transaction: tx, resolved: false)
      create(:anomaly, bookkeeping_transaction: tx, resolved: true)

      expect(Anomaly.unresolved).to contain_exactly(open)
    end
  end

  describe 'anomaly_type values' do
    it 'accepts the three documented anomaly types' do
      %w[unusual_amount potential_duplicate missing_metadata].each do |type|
        a = create(:anomaly, bookkeeping_transaction: tx, anomaly_type: type)
        expect(a.anomaly_type).to eq(type)
      end
    end
  end

  describe 'severity' do
    it 'stores the severity value verbatim' do
      a = create(:anomaly, bookkeeping_transaction: tx, severity: 'high')
      expect(a.severity).to eq('high')
    end
  end

  describe 'details JSONB' do
    it 'persists arbitrary hash data and round-trips with string keys' do
      a = create(:anomaly, bookkeeping_transaction: tx,
                 details: { 'mean' => 50.5, 'std_devs_above_mean' => 4.2 })
      expect(a.reload.details['mean']).to eq(50.5)
      expect(a.reload.details['std_devs_above_mean']).to eq(4.2)
    end
  end
end
