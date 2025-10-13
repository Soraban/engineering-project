class AnomalyFlag < ApplicationRecord
  # Associations
  belongs_to :transaction_record, class_name: 'Transaction', foreign_key: 'transaction_id'

  # Enums
  enum :anomaly_type, {
    unusual_amount: 0,
    potential_duplicate: 1,
    missing_metadata: 2,
    suspicious_pattern: 3
  }

  enum :severity, {
    low: 0,
    medium: 1,
    high: 2,
    critical: 3
  }

  validates :transaction_id, presence: true

  scope :unresolved, -> { where(resolved: false) }
  scope :recent, -> { order(created_at: :desc) }

  ANOMALY_SEVERITIES = {
    unusual_amount: :medium,
    potential_duplicate: :high,
    missing_metadata: :low,
    suspicious_pattern: :medium
  }.freeze

  # Instance methods
  def resolve!
    update!(resolved: true)
  end

  def mark_false_positive!
    update!(resolved: true, details: (details || {}).merge(false_positive: true))
  end

  def self.create_anomaly(type, transaction:, details:, severity: nil)
    find_or_create_by(transaction_record: transaction, anomaly_type: type) do |af|
      af.severity = severity || ANOMALY_SEVERITIES[type.to_sym]
      af.details = details
      af.resolved = false
    end
  end

  # Convenience methods that use the config
  def self.create_potential_duplicate(transaction:, details:)
    create_anomaly(:potential_duplicate, transaction: transaction, details: details)
  end

  def self.create_unusual_amount(transaction:, severity:, details:)
    create_anomaly(:unusual_amount, transaction: transaction, details: details, severity: severity)
  end

  def self.create_missing_metadata(transaction:, details:)
    create_anomaly(:missing_metadata, transaction: transaction, details: details)
  end

  def self.create_suspicious_pattern(transaction:, details:)
    create_anomaly(:suspicious_pattern, transaction: transaction, details: details)
  end
end
