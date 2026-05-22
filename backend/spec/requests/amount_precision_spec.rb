require 'rails_helper'
require 'csv'

# Verifies amounts survive the full pipeline without precision loss.
# The danger: amount is numeric(15,2) in Postgres but Rails/JSON/JS often
# coerce through Float, which can drift (49.99 -> 49.989999...).
RSpec.describe 'Amount precision through the pipeline', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'create -> DB round-trip' do
    it 'persists $49.99 exactly as BigDecimal(49.99)' do
      post '/api/v1/transactions',
        params: { transaction: { date: '2024-06-15', description: 'Test', amount: '49.99' } },
        as: :json

      tx = user.transactions.last
      expect(tx.amount).to eq(BigDecimal('49.99'))
    end

    it 'serializes $49.99 in the index response without precision loss' do
      create(:transaction, user: user, amount: BigDecimal('49.99'))

      get '/api/v1/transactions'

      amount_str = JSON.parse(response.body)['transactions'].first['amount']
      expect(BigDecimal(amount_str.to_s)).to eq(BigDecimal('49.99'))
    end

    it 'preserves a high-precision value like $1,234.56' do
      post '/api/v1/transactions',
        params: { transaction: { date: '2024-06-15', description: 'Test', amount: '1234.56' } },
        as: :json

      tx = user.transactions.last
      expect(tx.amount).to eq(BigDecimal('1234.56'))
    end

    it 'preserves negative amounts (refunds)' do
      post '/api/v1/transactions',
        params: { transaction: { date: '2024-06-15', description: 'Refund', amount: '-25.50' } },
        as: :json

      tx = user.transactions.last
      expect(tx.amount).to eq(BigDecimal('-25.50'))
    end

    it 'handles a large amount like $999,999.99 without losing cents' do
      post '/api/v1/transactions',
        params: { transaction: { date: '2024-06-15', description: 'Big', amount: '999999.99' } },
        as: :json

      tx = user.transactions.last
      expect(tx.amount).to eq(BigDecimal('999999.99'))
    end
  end

  describe 'CSV export round-trip' do
    it 'exports the exact stored amount with two decimal places' do
      create(:transaction, user: user, amount: BigDecimal('49.99'), description: 'Test', date: Date.today)

      get '/api/v1/transactions/export'

      row = CSV.parse(response.body, headers: true).first
      expect(row['amount']).to eq('49.99')
    end

    it 'exports a range of precision-sensitive values without drift' do
      values = %w[0.01 49.99 1234.56 999999.99]
      values.each do |v|
        create(:transaction, user: user, amount: BigDecimal(v), description: "val-#{v}")
      end

      get '/api/v1/transactions/export'

      rows = CSV.parse(response.body, headers: true)
      exported = rows.map { |r| [r['description'], r['amount']] }.to_h
      values.each do |v|
        expect(exported["val-#{v}"]).to eq(BigDecimal(v).to_s('F'))
      end
    end
  end

  describe 'CSV import preserves precision' do
    it 'imports $49.99 as exactly 49.99 (no float drift)' do
      csv = "date,description,amount,category\n2024-06-15,Test,49.99,\n"
      importer = CsvImporter.new(user: user, csv_content: csv)
      importer.import

      tx = user.transactions.last
      expect(tx.amount).to eq(BigDecimal('49.99'))
    end

    it 'strips $ and commas without losing precision' do
      csv = "date,description,amount,category\n2024-06-15,Test,\"$1,234.56\",\n"
      importer = CsvImporter.new(user: user, csv_content: csv)
      importer.import

      tx = user.transactions.last
      expect(tx.amount).to eq(BigDecimal('1234.56'))
    end
  end

  describe 'amount filtering / sorting precision' do
    it 'orders amounts correctly when they only differ in cents' do
      tx_a = create(:transaction, user: user, amount: BigDecimal('49.98'))
      tx_b = create(:transaction, user: user, amount: BigDecimal('49.99'))
      tx_c = create(:transaction, user: user, amount: BigDecimal('50.00'))

      get '/api/v1/transactions', params: { sort: 'amount', direction: 'asc' }

      ids = JSON.parse(response.body)['transactions'].map { |t| t['id'] }
      expect(ids).to eq([tx_a.id, tx_b.id, tx_c.id])
    end
  end
end
