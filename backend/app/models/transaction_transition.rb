class TransactionTransition < ApplicationRecord
  validates :sort_key, uniqueness: { scope: :transaction_id }

  belongs_to :bookkeeping_transaction, class_name: 'Transaction', foreign_key: 'transaction_id'

  after_destroy :update_most_recent, if: :most_recent?

  # Statesman::Adapters::ActiveRecordTransition tries to serialize metadata
  # but JSONB columns in Rails 7.2 are already natively handled. We include
  # the module's core behavior manually to avoid the serialize conflict.
  class_attribute :updated_timestamp_column
  self.updated_timestamp_column = :updated_at

  private

  def update_most_recent
    last_transition = bookkeeping_transaction.transaction_transitions.order(:sort_key).last
    return unless last_transition
    last_transition.update_column(:most_recent, true)
  end
end
