class TransactionStateMachine
  include Statesman::Machine

  state :pending, initial: true
  state :flagged
  state :reviewed

  transition from: :pending, to: [:flagged, :reviewed]
  transition from: :flagged, to: [:reviewed, :pending]
  # reviewed -> pending allowed as an explicit "undo / re-open" so users can
  # correct an accidental approve. Every transition is persisted to
  # transaction_transitions so the audit trail still tells the full story.
  transition from: :reviewed, to: [:flagged, :pending]

  after_transition(to: :pending) do |transaction, _transition|
    transaction.anomalies.unresolved.update_all(resolved: true, resolved_at: Time.current)
    transaction.update_column(:status, 'pending')
  end

  after_transition(to: :flagged) do |transaction, _transition|
    transaction.update_column(:status, 'flagged')
  end

  after_transition(to: :reviewed) do |transaction, _transition|
    transaction.update_column(:status, 'reviewed')
  end
end
