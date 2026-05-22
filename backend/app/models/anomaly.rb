class Anomaly < ApplicationRecord
  belongs_to :bookkeeping_transaction, class_name: 'Transaction', foreign_key: 'transaction_id'

  validates :anomaly_type, presence: true

  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
end
