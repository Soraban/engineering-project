require 'rails_helper'

RSpec.describe CategorizationRule, type: :model do
  describe "validations" do
    subject { described_class.new(pattern: "Amazon", category: "Shopping") }

    it "is valid with pattern and category" do
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
  end
end
