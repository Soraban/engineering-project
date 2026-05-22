class RuleHealthJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    total = Transaction.where(user_id: user_id).count
    return if total.zero?

    Rule.where(user_id: user_id).find_each do |rule|
      rule.update_columns(match_rate: rule.match_count.to_f / total)
    end
  end
end
