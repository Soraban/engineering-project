class AnomalyExplanationJob < ApplicationJob
  queue_as :ai

  def perform(anomaly_id)
    anomaly = Anomaly.includes(:bookkeeping_transaction).find_by(id: anomaly_id)
    return unless anomaly && anomaly.explanation.nil?

    tx = anomaly.bookkeeping_transaction
    context = build_context(anomaly, tx)
    explanation = AnthropicClient.explain_anomaly(context)

    anomaly.update_columns(
      explanation: explanation,
      explanation_generated_at: Time.current
    )
  end

  private

  def build_context(anomaly, tx)
    {
      anomaly_type:        anomaly.anomaly_type,
      severity:            anomaly.severity,
      transaction_date:    tx.date,
      transaction_amount:  tx.amount,
      transaction_desc:    tx.description.presence || '(no description)',
      details:             anomaly.details
    }
  end
end
