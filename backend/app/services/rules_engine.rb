class RulesEngine
  def self.apply(transaction, rules: nil)
    # Tiebreak same-priority rules by id (oldest first) so behavior is
    # deterministic when two rules share a priority number.
    rules ||= Rule.where(user_id: transaction.user_id, active: true).order(:priority, :id)
    applied_action_types = Set.new

    rules.each do |rule|
      next unless matches?(rule.condition, transaction)
      action_type = rule.action['type']

      next if applied_action_types.include?(action_type)

      fire_action(rule, transaction)
      applied_action_types.add(action_type)
      break unless rule.continue_processing
    end

    transaction.save! if transaction.changed?
  end

  def self.matches?(condition, transaction)
    field = condition['field']
    operator = condition['operator']
    value = condition['value']

    case operator
    when 'contains'
      return false if transaction.description.blank?
      transaction.description.downcase.include?(value.to_s.downcase)
    when 'matches'
      return false if transaction.description.blank?
      begin
        Regexp.new(value.to_s, Regexp::IGNORECASE).match?(transaction.description)
      rescue RegexpError
        Rails.logger.warn("Invalid regex in rule condition: #{value}")
        false
      end
    when 'gt'
      transaction.amount.present? && transaction.amount > BigDecimal(value.to_s)
    when 'lt'
      transaction.amount.present? && transaction.amount < BigDecimal(value.to_s)
    when 'eq'
      transaction.amount.present? && transaction.amount == BigDecimal(value.to_s)
    when 'is'
      case field
      when 'category'
        transaction.category.to_s.downcase == value.to_s.downcase
      else
        false
      end
    else
      false
    end
  end

  def self.fire_action(rule, transaction)
    action = rule.action

    case action['type']
    when 'set_category'
      transaction.category = action['value']
    when 'flag_high_value'
      flags = transaction.anomaly_flags || []
      transaction.anomaly_flags = (flags + ['high_value']).uniq
    when 'add_tag'
      metadata = transaction.metadata || {}
      tags = metadata['tags'] || []
      metadata['tags'] = (tags + [action['value']]).uniq
      transaction.metadata = metadata
    end

    rule.increment!(:match_count)
    rule.update_columns(last_matched_at: Time.current)
  end
end
