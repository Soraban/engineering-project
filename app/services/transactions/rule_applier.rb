# frozen_string_literal: true

module Transactions
  class RuleApplier
    def initialize(transaction)
      @transaction = transaction
    end

    def call
      CategorizationRule.where(active: true).find_each do |rule|
        case rule.kind
        when "description_contains"
          apply_description_contains(rule)
        when "amount_greater_than"
          apply_amount_greater_than(rule)
        end
      end

      @transaction
    end

    private

    def apply_description_contains(rule)
      return unless @transaction.category.blank?
      return if rule.pattern.blank? || rule.category.blank?

      if @transaction.description.to_s.downcase.include?(rule.pattern.downcase)
        @transaction.category = rule.category
      end
    end

    def apply_amount_greater_than(rule)
      return if rule.min_amount.nil?
      return if @transaction.amount.nil?

      if @transaction.amount > rule.min_amount
        @transaction.flagged = true
        @transaction.flag_reason = "High Value"
      end
    end
  end
end
