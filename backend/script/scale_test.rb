# Generates enough transactions to reach TARGET for the demo user, then runs
# EXPLAIN ANALYZE on the three production hot-path queries.
#
# Run from backend/:
#   bin/rails runner script/scale_test.rb
#
# Override target:
#   TARGET=500000 bin/rails runner script/scale_test.rb
#
# Designed for local benchmarking — do NOT run against production.

require 'benchmark'

TARGET = (ENV['TARGET'] || 1_000_000).to_i
BATCH  = 1_000

CATEGORIES = ['Shopping', 'Food & Dining', 'Entertainment', 'Housing', 'Transportation',
              'Utilities', 'Healthcare', 'Travel', 'Education', 'Subscriptions', nil].freeze
MERCHANTS = ['Amazon Purchase', 'Whole Foods', 'Netflix', 'Spotify', 'Uber',
             'Starbucks', 'Costco', 'Shell Gas', 'Target', 'Walmart',
             'AMZN MKTP US', 'CVS Pharmacy', 'Trader Joes', 'Doordash', 'Lyft'].freeze

user = User.find_by!(email: 'demo@test.com')
existing = Transaction.where(user_id: user.id).count
to_create = [TARGET - existing, 0].max

puts "User: #{user.email}"
puts "Existing transactions: #{existing}"
puts "Target: #{TARGET}"
puts "To create: #{to_create}"

if to_create.positive?
  puts "\nGenerating #{to_create} synthetic transactions in batches of #{BATCH}..."

  now = Time.current
  total_batches = (to_create.to_f / BATCH).ceil
  elapsed = Benchmark.realtime do
    total_batches.times do |i|
      remaining = to_create - (i * BATCH)
      this_batch = [remaining, BATCH].min

      rows = this_batch.times.map do
        desc = MERCHANTS.sample
        {
          user_id: user.id,
          date: rand(365).days.ago.to_date,
          description: desc,
          description_normalized: Transaction.normalize_description(desc),
          amount: rand(5.0..500.0).round(2),
          category: CATEGORIES.sample,
          status: 'pending',
          source: 'csv',
          anomaly_flags: [],
          metadata: {},
          created_at: now,
          updated_at: now
        }
      end
      Transaction.insert_all(rows)

      if (i + 1) % 50 == 0
        printf("  %d / %d batches  (%d rows)\n", i + 1, total_batches, (i + 1) * BATCH)
      end
    end
  end

  rate = (to_create / elapsed).round
  puts "\nInserted #{to_create} rows in #{elapsed.round(1)}s  (#{rate.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} rows/sec)"
end

final = Transaction.where(user_id: user.id).count
puts "\nFinal row count for #{user.email}: #{final.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

puts "\n" + "=" * 70
puts "EXPLAIN ANALYZE — production hot-path queries"
puts "=" * 70

connection = ActiveRecord::Base.connection

queries = {
  'Review queue  (filter by status, sort by date, limit 50)' =>
    "EXPLAIN ANALYZE SELECT * FROM transactions WHERE user_id = #{user.id} " \
    "AND status != 'reviewed' ORDER BY date DESC LIMIT 50",

  'Keyset pagination  (default sort, id DESC, limit 50)' =>
    "EXPLAIN ANALYZE SELECT * FROM transactions WHERE user_id = #{user.id} " \
    "ORDER BY id DESC LIMIT 50",

  'Full-text search  (GIN index on description)' =>
    "EXPLAIN ANALYZE SELECT * FROM transactions WHERE user_id = #{user.id} " \
    "AND to_tsvector('english', coalesce(description, '')) @@ plainto_tsquery('amazon')",
}

queries.each do |label, sql|
  puts "\n--- #{label} ---"
  result = connection.execute(sql)
  result.each { |row| puts row['QUERY PLAN'] }
end

puts "\nDone."
