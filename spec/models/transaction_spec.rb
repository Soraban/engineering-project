require 'rails_helper'

RSpec.describe Transaction do
  describe "validations" do
    subject { Transaction.new(date: Date.current, description: "Coffee", amount: "5.99") }

    it "is valid with date, description, and amount" do
      expect(subject).to be_valid
    end

    it "is invalid without a date" do
      subject.date = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:date]).to include("can't be blank")
    end

    it "is invalid without a description" do
      subject.description = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:description]).to include("can't be blank")
    end

    it "is invalid without an amount" do
      subject.amount = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:amount]).to include("can't be blank")
    end

    it "is invalid when amount is not a number" do
      subject.amount = "not a number"
      expect(subject).not_to be_valid
      expect(subject.errors[:amount]).to be_present
    end

    it "is valid without a category" do
      subject.category = nil
      expect(subject).to be_valid
    end
  end
end
