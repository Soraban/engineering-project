# frozen_string_literal: true

namespace :dev do
  desc "Seed a large number of transactions quickly. Usage: rake dev:seed_transactions COUNT=1000000 BATCH=10000"
  task seed_transactions: :environment do
    count = (ENV["COUNT"] || "1000000").to_i
    batch = (ENV["BATCH"] || "10000").to_i

    raise "COUNT must be > 0" if count <= 0
    raise "BATCH must be between 1 and 50_000" if batch <= 0 || batch > 50_000

    categories = ["Food", "Shopping", "Housing", "Utilities", "Travel", nil, ""]
    descriptions = ["amazon", "rent", "uber", "coffee", "grocery", "netflix", "gym", "insurance"]

    puts "Seeding #{count} transactions in batches of #{batch}..."

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    created = 0

    while created < count
      remaining = count - created
      size = [batch, remaining].min
      now = Time.current

      rows = Array.new(size) do |i|
        # Spread dates across ~2 years
        d = Date.current - ((created + i) % 730)

        amount_cents = rand(199..200_000) # $1.99 to $2000.00
        amount = BigDecimal(amount_cents) / 100

        category = categories.sample
        flagged = false
        flag_reason = nil

        # Sprinkle some flagged anomalies (optional)
        if rand < 0.002
          flagged = true
          flag_reason = "High Value"
        end

        {
          date: d,
          description: descriptions.sample,
          amount: amount,
          category: category.presence,
          flagged: flagged,
          flag_reason: flag_reason,
          created_at: now,
          updated_at: now
        }
      end

      Transaction.insert_all(rows)
      created += size

      if (created % (batch * 10)).zero?
        puts "Inserted #{created}/#{count}..."
      end
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    puts "Done. Inserted #{count} in #{elapsed.round(2)}s (#{(count / elapsed).round} rows/sec)"
  end
end
