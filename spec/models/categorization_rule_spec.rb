require "rails_helper"

RSpec.describe CategorizationRule, type: :model do
  describe "validations" do
    context "when kind is description_contains" do
      subject do
        described_class.new(
          kind: "description_contains",
          pattern: "amazon",
          category: "Shopping",
          active: true
        )
      end

      it "is valid with kind, pattern, and category" do
        expect(subject).to be_valid
      end

      it "is invalid without a pattern" do
        subject.pattern = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:pattern]).to include("can't be blank")
      end

      it "is invalid without a category" do
        subject.category = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:category]).to include("can't be blank")
      end

      it "does not require min_amount" do
        subject.min_amount = nil
        expect(subject).to be_valid
      end
    end

    context "when kind is amount_greater_than" do
      subject do
        described_class.new(
          kind: "amount_greater_than",
          min_amount: BigDecimal("1000.00"),
          active: true
        )
      end

      it "is valid with kind and min_amount" do
        expect(subject).to be_valid
      end

      it "is invalid without min_amount" do
        subject.min_amount = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:min_amount]).to include("can't be blank")
      end

      it "does not require pattern or category" do
        subject.pattern = nil
        subject.category = nil
        expect(subject).to be_valid
      end
    end

    context "when kind is invalid" do
      subject { described_class.new(kind: "nope") }

      it "is invalid" do
        expect(subject).not_to be_valid
        expect(subject.errors[:kind]).to include("is not included in the list")
      end
    end
  end
end
