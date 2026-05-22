class AnomalySerializer < Blueprinter::Base
  identifier :id

  fields :anomaly_type, :severity, :details, :explanation,
         :explanation_generated_at, :resolved, :resolved_at, :created_at

  field :transaction_id

  view :with_transaction do
    association :bookkeeping_transaction, blueprint: TransactionSerializer, name: :transaction
  end
end
