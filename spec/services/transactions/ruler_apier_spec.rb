require "rails_helper"

RSpec.describe Transactions::RuleApplier do
  describe "#call" do
    it "categorizes by description_contains when category is blank" do
      CategorizationRule.create!(
        kind: "description_contains",
        pattern: "amazon",
        category: "Shopping",
        active: true
      )

      tx = Transaction.new(date: Date.current, description: "Amazon Prime", amount: 10.00, category: nil)

      described_class.new(tx).call

      expect(tx.category).to eq("Shopping")
    end

    it "does not override an existing category" do
      CategorizationRule.create!(
        kind: "description_contains",
        pattern: "amazon",
        category: "Shopping",
        active: true
      )

      tx = Transaction.new(date: Date.current, description: "Amazon Prime", amount: 10.00, category: "Food")

      described_class.new(tx).call

      expect(tx.category).to eq("Food")
    end

    it "flags high value transactions with amount_greater_than" do
      CategorizationRule.create!(
        kind: "amount_greater_than",
        min_amount: 1000.00,
        active: true
      )

      tx = Transaction.new(date: Date.current, description: "Rent", amount: 1500.00)

      described_class.new(tx).call

      expect(tx.flagged).to eq(true)
      expect(tx.flag_reason).to eq("High Value")
    end

    it "ignores inactive rules" do
      CategorizationRule.create!(
        kind: "description_contains",
        pattern: "amazon",
        category: "Shopping",
        active: false
      )

      tx = Transaction.new(date: Date.current, description: "Amazon Prime", amount: 10.00)

      described_class.new(tx).call

      expect(tx.category).to be_blank
    end
  end
end
