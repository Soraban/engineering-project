require "rails_helper"

RSpec.describe "Transactions bulk update", type: :request do
  describe "PATCH /api/transactions/bulk_update" do
    it "updates category for selected transactions" do
      t1 = Transaction.create!(date: Date.current, description: "A", amount: 1.00, category: nil)
      t2 = Transaction.create!(date: Date.current, description: "B", amount: 2.00, category: "")

      patch "/api/transactions/bulk_update", params: {
        transaction_ids: [ t1.id, t2.id ],
        category: "Food"
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["updated"]).to eq(2)

      expect(t1.reload.category).to eq("Food")
      expect(t2.reload.category).to eq("Food")
    end

    it "returns an error when no ids are provided" do
      patch "/api/transactions/bulk_update", params: { transaction_ids: [], category: "Food" }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("No transactions selected")
    end

    it "returns an error when category is blank" do
      t1 = Transaction.create!(date: Date.current, description: "A", amount: 1.00)

      patch "/api/transactions/bulk_update", params: { transaction_ids: [ t1.id ], category: "   " }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Category is required")
    end
  end
end
