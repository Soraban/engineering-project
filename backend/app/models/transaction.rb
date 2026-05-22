class Transaction < ApplicationRecord
  include Statesman::Adapters::ActiveRecordQueries[
    transition_class: TransactionTransition,
    initial_state: :pending
  ]
  include PgSearch::Model

  belongs_to :user
  has_many :anomalies, dependent: :destroy
  has_many :transaction_transitions, autosave: false, dependent: :destroy

  validates :date, presence: true
  validates :amount, presence: true, numericality: true

  before_save :compute_normalized_description

  pg_search_scope :search_description,
    against: :description,
    using: {
      tsearch: { prefix: true },
      trigram: { threshold: 0.3 }
    }

  scope :flagged, -> { where(status: 'flagged') }
  scope :pending, -> { where(status: 'pending') }
  scope :reviewed, -> { where(status: 'reviewed') }
  scope :uncategorized, -> { where(category: [nil, '']) }

  def state_machine
    @state_machine ||= TransactionStateMachine.new(self, transition_class: TransactionTransition)
  end

  def self.transition_class
    TransactionTransition
  end

  def self.initial_state
    :pending
  end

  def self.normalize_description(desc)
    return nil if desc.blank?
    desc
      .downcase
      .gsub(/\*[a-z0-9]{4,}/i, '')
      .gsub(/#\d+/, '')
      .gsub(/\s+/, ' ')
      .strip
  end

  private

  def compute_normalized_description
    self.description_normalized = self.class.normalize_description(description)
  end
end
