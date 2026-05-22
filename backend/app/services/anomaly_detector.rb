class AnomalyDetector
  MINIMUM_BASELINE = 10
  STD_DEV_THRESHOLD = 3
  DUPLICATE_WINDOW = 48.hours

  def self.check(transaction)
    flags = []

    flags.concat(check_unusual_amount(transaction))
    flags.concat(check_duplicate(transaction))
    flags.concat(check_missing_metadata(transaction))

    if flags.any?
      severity = compute_severity(
        flags: flags.map { |f| f[:type] },
        std_devs_above_mean: flags.find { |f| f[:type] == 'unusual_amount' }&.dig(:std_devs) || 0
      )

      flags.each do |flag|
        anomaly = Anomaly.create!(
          bookkeeping_transaction: transaction,
          anomaly_type: flag[:type],
          severity: severity,
          details: flag[:details] || {}
        )
        AnomalyExplanationJob.perform_later(anomaly.id)
        # Live-push the new anomaly to any Dashboard tab the user has open.
        # Frontend invalidates the dashboard query so the new row appears
        # without a page reload.
        ActionCable.server.broadcast(
          "anomalies_for_user_#{transaction.user_id}",
          { type: 'new_anomaly', anomaly_type: flag[:type], severity: severity, transaction_id: transaction.id }
        )
      end

      all_flags = (transaction.anomaly_flags || []) + flags.map { |f| f[:type] }
      transaction.update_column(:anomaly_flags, all_flags.uniq)

      if transaction.state_machine.can_transition_to?(:flagged)
        transaction.state_machine.transition_to!(:flagged)
      end
    end
  end

  def self.check_unusual_amount(transaction)
    user_transactions = Transaction.where(user_id: transaction.user_id)
                                   .where.not(id: transaction.id)
                                   .where('date >= ?', 90.days.ago)

    return [] if user_transactions.count < MINIMUM_BASELINE

    stats = user_transactions.pick(
      Arel.sql('AVG(amount)'),
      Arel.sql('STDDEV_SAMP(amount)')
    )
    mean = stats[0].to_f
    std_dev = stats[1].to_f

    return [] if std_dev.zero?

    threshold = mean + (STD_DEV_THRESHOLD * std_dev)
    return [] unless transaction.amount > threshold

    std_devs_above = ((transaction.amount.to_f - mean) / std_dev).round(1)

    [{
      type: 'unusual_amount',
      std_devs: std_devs_above,
      details: { mean: mean.round(2), std_dev: std_dev.round(2), std_devs_above_mean: std_devs_above }
    }]
  end

  def self.check_duplicate(transaction)
    normalized = Transaction.normalize_description(transaction.description)
    return [] if normalized.blank?

    duplicates = Transaction.where(user_id: transaction.user_id)
                            .where.not(id: transaction.id)
                            .where(date: transaction.date, amount: transaction.amount, description_normalized: normalized)
                            .where('created_at >= ?', DUPLICATE_WINDOW.ago)

    return [] unless duplicates.exists?

    [{
      type: 'potential_duplicate',
      details: { matching_transaction_ids: duplicates.pluck(:id) }
    }]
  end

  def self.check_missing_metadata(transaction)
    return [] if transaction.description.present? && transaction.description.strip.present?

    [{ type: 'missing_metadata', details: { missing_fields: ['description'] } }]
  end

  def self.compute_severity(flags:, std_devs_above_mean: 0)
    score = 0
    score += 10 if flags.include?('missing_metadata')
    score += 25 if flags.include?('potential_duplicate')
    if flags.include?('unusual_amount')
      score += 20 + ([std_devs_above_mean - 3, 0].max * 5).to_i
    end

    case score
    when 0..20 then 'low'
    when 21..49 then 'medium'
    else 'high'
    end
  end
end
