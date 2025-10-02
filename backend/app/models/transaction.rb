class Transaction < ApplicationRecord
  belongs_to :category, optional: true

  validates :transaction_date, presence: true
  validates :amount, presence: true, numericality: true

  scope :uncategorized, -> { where(category_id: nil) }
  scope :categorized, -> { where.not(category_id: nil) }
  scope :flagged, -> { where(flagged_as_anomaly: true) }
  scope :reviewed, -> { where(reviewed: true) }
  scope :unreviewed, -> { where(reviewed: false) }
  scope :needs_review, -> { where(reviewed: false).where(flagged_as_anomaly: true).or(where(reviewed: false, category_id: nil)) }

  after_create :enqueue_processing
  after_commit :clear_dashboard_cache

  def self.import_from_csv(file)
    require 'csv'
    results = { success: 0, failed: 0, errors: [] }

    CSV.foreach(file.path, headers: true, header_converters: :symbol) do |row|
      begin
        # Handle different CSV formats
        transaction = new(
          transaction_date: parse_date(row[:date] || row[:transaction_date]),
          description: row[:description]&.strip,
          amount: parse_amount(row[:amount]),
          metadata: row.to_h.except(:date, :transaction_date, :description, :amount)
        )

        if transaction.save
          results[:success] += 1
        else
          results[:failed] += 1
          results[:errors] << { row: row.to_h, errors: transaction.errors.full_messages }
        end
      rescue => e
        results[:failed] += 1
        results[:errors] << { row: row.to_h, error: e.message }
      end
    end

    results
  end

  private

  def enqueue_processing
    TransactionProcessorJob.perform_later(self.id)
  end

  def clear_dashboard_cache
    Rails.cache.delete('review_dashboard')
  end

  def self.parse_date(date_string)
    return Date.today if date_string.blank?
    Date.parse(date_string.to_s)
  rescue
    Date.today
  end

  def self.parse_amount(amount_string)
    return 0 if amount_string.blank?
    # Remove currency symbols and commas
    amount_string.to_s.gsub(/[$,]/, '').to_f
  end
end
