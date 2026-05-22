class TransactionSerializer < Blueprinter::Base
  identifier :id

  fields :date, :description, :description_normalized, :amount, :category,
         :status, :source, :anomaly_flags, :metadata, :created_at, :updated_at

  view :detail do
    association :anomalies, blueprint: AnomalySerializer
  end
end
