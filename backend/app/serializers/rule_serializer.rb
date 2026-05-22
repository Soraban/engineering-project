class RuleSerializer < Blueprinter::Base
  identifier :id

  fields :name, :condition, :action, :priority, :active, :continue_processing,
         :match_count, :last_matched_at, :match_rate, :created_at, :updated_at

  field :stale do |rule|
    rule.stale?
  end

  field :overbroad do |rule|
    rule.overbroad?
  end
end
