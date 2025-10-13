class Transaction < ApplicationRecord
  # Enums
  enum :status, { pending: 0, approved: 1, reviewed: 2 }, default: :pending

  # Associations
  belongs_to :category, optional: true
  has_many :anomaly_flags, dependent: :destroy

  # Validations
  validates :date, presence: true
  validates :amount, presence: true, numericality: true
  
  # Callbacks
  before_validation :clean_description
  before_validation :set_description_hash
  after_update :recheck_anomalies, if: :saved_change_to_amount?
  after_commit :clear_cached_stats

  # Scopes for performance and filtering (only actively used ones)
  scope :uncategorized, -> { where(category_id: nil) }
  scope :flagged, -> { where(flagged: true) }
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(date: :desc, created_at: :desc) }

  # Class methods
  def self.bulk_categorize(transaction_ids, category_id)
    where(id: transaction_ids).update_all(category_id: category_id, updated_at: Time.current)
  end

  # Instance methods
  def needs_review?
    flagged? || category_id.blank? || anomaly_flags.unresolved.exists?
  end

  def mark_reviewed!
    update!(status: :reviewed, flagged: false)
    anomaly_flags.update_all(resolved: true)
  end

  private

  def clean_description
    self.description = StringUtils.clean_spaces(description)
  end

  def set_description_hash
    self.description_hash = StringUtils.normalize_and_hash(description)
  end

  def recheck_anomalies
    AnomalyDetectionJob.perform_later(id)
  end

  def clear_cached_stats
    TransactionStatsService.clear_caches
  end
end
