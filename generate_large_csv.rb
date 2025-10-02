#!/usr/bin/env ruby
# Generates a large CSV file with realistic transaction data for testing scalability

require 'csv'
require 'date'

# Configuration
NUM_TRANSACTIONS = ENV.fetch('NUM_TRANSACTIONS', 10_000).to_i
OUTPUT_FILE = ENV.fetch('OUTPUT_FILE', 'large_transactions.csv')

# Sample data
MERCHANTS = [
  'Starbucks Coffee', 'Whole Foods Market', 'Shell Gas Station', 'Amazon.com',
  'Netflix Subscription', 'Spotify Premium', 'Uber Ride', 'Lyft Ride',
  'Target Store', 'Walmart', 'Costco Wholesale', 'Home Depot', 'Lowes',
  'CVS Pharmacy', 'Walgreens', 'Best Buy', 'Apple Store', 'Microsoft Store',
  'Chipotle Mexican Grill', 'McDonalds', 'Subway', 'Taco Bell', 'Pizza Hut',
  'Electric Bill Payment', 'Water Bill Payment', 'Internet Bill Payment',
  'Rent Payment', 'Mortgage Payment', 'Car Payment', 'Insurance Premium',
  'Gym Membership', 'Yoga Studio', 'Salon & Spa', 'Barbershop',
  'Movie Theater', 'Concert Tickets', 'Hotel Booking', 'Airline Tickets',
  'Restaurant Dinner', 'Coffee Shop', 'Bar & Grill', 'Fast Food',
  'Grocery Store', 'Gas Station', 'Parking Meter', 'Toll Road',
  'Doctor Visit', 'Dentist Appointment', 'Veterinarian', 'Pet Store',
  'Bookstore', 'Library Fine', 'School Supplies', 'Tuition Payment'
]

# Amount ranges for different merchant types
AMOUNT_RANGES = {
  'Coffee' => [3.50, 8.50],
  'Gas Station' => [30.00, 80.00],
  'Grocery' => [20.00, 250.00],
  'Restaurant' => [15.00, 150.00],
  'Subscription' => [9.99, 19.99],
  'Ride' => [8.00, 45.00],
  'Store' => [25.00, 500.00],
  'Bill Payment' => [50.00, 350.00],
  'Rent' => [1200.00, 3500.00],
  'Mortgage' => [1500.00, 4000.00],
  'Insurance' => [150.00, 500.00],
  'Entertainment' => [10.00, 200.00],
  'Healthcare' => [50.00, 500.00],
  'Education' => [100.00, 5000.00]
}

def get_amount_range(merchant)
  case merchant
  when /Coffee|Starbucks/
    AMOUNT_RANGES['Coffee']
  when /Gas Station|Shell/
    AMOUNT_RANGES['Gas Station']
  when /Grocery|Foods|Costco|Walmart/
    AMOUNT_RANGES['Grocery']
  when /Restaurant|Grill|McDonalds|Subway|Taco|Pizza|Bar/
    AMOUNT_RANGES['Restaurant']
  when /Subscription|Netflix|Spotify/
    AMOUNT_RANGES['Subscription']
  when /Uber|Lyft/
    AMOUNT_RANGES['Ride']
  when /Target|Store|Best Buy|Apple|Microsoft|Home Depot|Lowes/
    AMOUNT_RANGES['Store']
  when /Bill|Electric|Water|Internet/
    AMOUNT_RANGES['Bill Payment']
  when /Rent/
    AMOUNT_RANGES['Rent']
  when /Mortgage/
    AMOUNT_RANGES['Mortgage']
  when /Insurance/
    AMOUNT_RANGES['Insurance']
  when /Movie|Concert|Hotel|Airline/
    AMOUNT_RANGES['Entertainment']
  when /Doctor|Dentist|Veterinarian|Healthcare/
    AMOUNT_RANGES['Healthcare']
  when /School|Tuition|Education/
    AMOUNT_RANGES['Education']
  else
    [10.00, 100.00]
  end
end

def generate_amount(merchant)
  range = get_amount_range(merchant)
  amount = rand(range[0]..range[1])
  amount.round(2)
end

def generate_date(index, total)
  # Distribute transactions over the past 2 years
  days_ago = (730.0 * index / total).to_i
  (Date.today - days_ago).to_s
end

puts "Generating #{NUM_TRANSACTIONS} transactions..."
puts "Output file: #{OUTPUT_FILE}"

start_time = Time.now

CSV.open(OUTPUT_FILE, 'w') do |csv|
  # Write header
  csv << ['date', 'description', 'amount']

  # Generate transactions
  NUM_TRANSACTIONS.times do |i|
    merchant = MERCHANTS.sample
    date = generate_date(i, NUM_TRANSACTIONS)
    amount = generate_amount(merchant)

    # Add some variation to descriptions
    description = merchant
    if rand < 0.1 # 10% chance of location suffix
      description += " - #{['Downtown', 'Mall', 'Airport', 'Main St', 'Online'].sample}"
    end

    csv << [date, description, amount]

    # Progress indicator
    if (i + 1) % 1000 == 0
      elapsed = Time.now - start_time
      rate = (i + 1) / elapsed
      remaining = (NUM_TRANSACTIONS - i - 1) / rate
      puts "Generated #{i + 1}/#{NUM_TRANSACTIONS} transactions (#{rate.round(0)} tx/sec, ~#{remaining.round(0)}s remaining)"
    end
  end
end

elapsed = Time.now - start_time
puts "\n✓ Successfully generated #{NUM_TRANSACTIONS} transactions in #{elapsed.round(2)} seconds"
puts "✓ File size: #{File.size(OUTPUT_FILE) / 1024.0 / 1024.0}MB"
puts "✓ Output: #{OUTPUT_FILE}"
puts "\nTo generate a different number of transactions:"
puts "  NUM_TRANSACTIONS=100000 ruby generate_large_csv.rb"
puts "\nTo specify output filename:"
puts "  OUTPUT_FILE=my_transactions.csv ruby generate_large_csv.rb"
