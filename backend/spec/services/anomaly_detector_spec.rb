require 'rails_helper'

RSpec.describe AnomalyDetector do
  let(:user) { create(:user) }

  before do
    allow(AnomalyExplanationJob).to receive(:perform_later)
  end

  describe 'unusual amount detection' do
    before do
      90.times do |i|
        create(:transaction, user: user,
          amount: 45 + rand(10),
          date: i.days.ago.to_date)
      end
    end

    it 'flags a transaction 3+ std devs above the mean' do
      tx = create(:transaction, user: user, amount: 8500.00, date: Date.today)
      AnomalyDetector.check(tx)

      expect(tx.reload.anomaly_flags).to include('unusual_amount')
      expect(Anomaly.find_by(transaction_id: tx.id, anomaly_type: 'unusual_amount')).to be_present
    end

    it 'does not flag a transaction within normal range' do
      tx = create(:transaction, user: user, amount: 55.00, date: Date.today)
      AnomalyDetector.check(tx)

      expect(tx.reload.anomaly_flags).not_to include('unusual_amount')
    end

    it 'does not flag when user has fewer than 10 transactions (insufficient baseline)' do
      new_user = create(:user)
      create_list(:transaction, 5, user: new_user, amount: 50)
      tx = create(:transaction, user: new_user, amount: 9999.00)

      AnomalyDetector.check(tx)
      expect(tx.reload.anomaly_flags).not_to include('unusual_amount')
    end
  end

  describe 'duplicate detection' do
    it 'flags a transaction with same date, amount, and description within 48 hours' do
      create(:transaction, user: user,
        date: Date.today, amount: 49.99, description: 'Amazon Purchase',
        created_at: 2.hours.ago)
      duplicate = create(:transaction, user: user,
        date: Date.today, amount: 49.99, description: 'Amazon Purchase')

      AnomalyDetector.check(duplicate)
      expect(duplicate.reload.anomaly_flags).to include('potential_duplicate')
    end

    it 'does not flag when same amount but different description' do
      create(:transaction, user: user,
        date: Date.today, amount: 49.99, description: 'Amazon Purchase')
      tx = create(:transaction, user: user,
        date: Date.today, amount: 49.99, description: 'Spotify')

      AnomalyDetector.check(tx)
      expect(tx.reload.anomaly_flags).not_to include('potential_duplicate')
    end

    it 'matches on normalized descriptions (strips reference codes)' do
      create(:transaction, user: user,
        date: Date.today, amount: 49.99, description: 'AMAZON MKTP US*2F4KL9',
        created_at: 1.hour.ago)
      tx = create(:transaction, user: user,
        date: Date.today, amount: 49.99, description: 'AMAZON MKTP US*8B2MQ1')

      AnomalyDetector.check(tx)
      expect(tx.reload.anomaly_flags).to include('potential_duplicate')
    end
  end

  describe 'missing metadata detection' do
    it 'flags a transaction with nil description' do
      tx = create(:transaction, user: user, description: nil)
      AnomalyDetector.check(tx)

      expect(tx.reload.anomaly_flags).to include('missing_metadata')
      expect(Anomaly.find_by(transaction_id: tx.id, anomaly_type: 'missing_metadata')).to be_present
    end

    it 'flags a transaction with blank description' do
      tx = create(:transaction, user: user, description: '   ')
      AnomalyDetector.check(tx)

      expect(tx.reload.anomaly_flags).to include('missing_metadata')
    end

    it 'does not flag when description is present' do
      tx = create(:transaction, user: user, description: 'Starbucks')
      AnomalyDetector.check(tx)

      expect(tx.reload.anomaly_flags).not_to include('missing_metadata')
    end
  end

  describe 'multiple anomalies on one transaction' do
    it 'can flag both unusual amount and missing metadata simultaneously' do
      90.times { |i| create(:transaction, user: user, amount: 45 + rand(10), date: 30.days.ago.to_date) }
      tx = create(:transaction, user: user, amount: 8500.00, description: nil)

      AnomalyDetector.check(tx)
      flags = tx.reload.anomaly_flags
      expect(flags).to include('unusual_amount', 'missing_metadata')
    end
  end

  describe '.compute_severity' do
    it 'returns low for missing_metadata only' do
      expect(AnomalyDetector.compute_severity(flags: ['missing_metadata'])).to eq('low')
    end

    it 'returns medium for potential_duplicate' do
      expect(AnomalyDetector.compute_severity(flags: ['potential_duplicate'])).to eq('medium')
    end

    it 'returns high for combined anomalies' do
      expect(AnomalyDetector.compute_severity(
        flags: ['potential_duplicate', 'unusual_amount'],
        std_devs_above_mean: 6
      )).to eq('high')
    end
  end
end
