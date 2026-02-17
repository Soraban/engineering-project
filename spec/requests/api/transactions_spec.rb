require "rails_helper"

RSpec.describe "Api::Transactions", type: :request do
  describe "GET /api/transactions" do
    it "returns transactions" do
      Transaction.create!(
        date: Date.current,
        description: "Coffee",
        amount: 5.99
      )

      get "/api/transactions"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
    end
  end

  describe "POST /api/transactions" do
    it "creates a transaction" do
      post "/api/transactions", params: {
        transaction: {
          date: Date.current,
          description: "Lunch",
          amount: 12.50
        }
      }

      expect(response).to have_http_status(:created)
      expect(Transaction.count).to eq(1)
    end

    it "returns errors for invalid data" do
      post "/api/transactions", params: {
        transaction: { description: "Missing fields" }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/transactions/review" do
    it "returns flagged and uncategorized transactions" do
      flagged_tx = Transaction.create!(
        date: Date.parse("2026-02-16"),
        description: "rent",
        amount: BigDecimal("1500.00"),
        category: "Housing",
        flagged: true,
        flag_reason: "High Value"
      )

      uncategorized_tx = Transaction.create!(
        date: Date.parse("2026-02-15"),
        description: "coffee",
        amount: BigDecimal("5.99"),
        category: nil,
        flagged: false
      )

      _normal_tx = Transaction.create!(
        date: Date.parse("2026-02-14"),
        description: "groceries",
        amount: BigDecimal("45.00"),
        category: "Food",
        flagged: false
      )

      get "/api/transactions/review"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body.keys).to contain_exactly("flagged", "uncategorized")

      flagged_ids = body["flagged"].map { |t| t["id"] }
      uncategorized_ids = body["uncategorized"].map { |t| t["id"] }

      expect(flagged_ids).to include(flagged_tx.id)
      expect(uncategorized_ids).to include(uncategorized_tx.id)
    end

    it "respects the limit parameter" do
      3.times do |i|
        Transaction.create!(
          date: Date.parse("2026-02-16"),
          description: "flagged#{i}",
          amount: BigDecimal("1500.00"),
          category: "Housing",
          flagged: true,
          flag_reason: "High Value"
        )
      end

      get "/api/transactions/review", params: { limit: 2 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body["flagged"].length).to eq(2)
    end
  end

  describe "PATCH /api/transactions/:id" do
    it "approves a flagged transaction by clearing flagged and flag_reason" do
      tx = Transaction.create!(
        date: Date.parse("2026-02-16"),
        description: "rent",
        amount: BigDecimal("1500.00"),
        category: "Housing",
        flagged: true,
        flag_reason: "High Value"
      )

      patch "/api/transactions/#{tx.id}", params: {
        transaction: { flagged: false }
      }

      expect(response).to have_http_status(:ok)

      tx.reload
      expect(tx.flagged).to eq(false)
      expect(tx.flag_reason).to be_nil
    end

    it "edits a transaction (e.g., category) successfully" do
      tx = Transaction.create!(
        date: Date.parse("2026-02-16"),
        description: "amazon",
        amount: BigDecimal("12.99"),
        category: nil,
        flagged: false
      )

      patch "/api/transactions/#{tx.id}", params: {
        transaction: { category: "Shopping" }
      }

      expect(response).to have_http_status(:ok)

      tx.reload
      expect(tx.category).to eq("Shopping")
    end
  end

  describe "DELETE /api/transactions/:id" do
    it "deletes a transaction" do
      tx = Transaction.create!(
        date: Date.parse("2026-02-16"),
        description: "coffee",
        amount: BigDecimal("5.99"),
        category: "Food"
      )

      expect {
        delete "/api/transactions/#{tx.id}"
      }.to change(Transaction, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "GET /api/transactions pagination" do
    before do
      5.times do |i|
        Transaction.create!(
          date: Date.today,
          description: "tx#{i}",
          amount: 10
        )
      end
    end

    it "respects limit parameter" do
      get "/api/transactions", params: { limit: 2 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body.length).to eq(2)
    end

    it "respects offset parameter" do
      get "/api/transactions", params: { limit: 2, offset: 2 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body.length).to eq(2)
    end

    it "caps limit to max allowed value" do
      get "/api/transactions", params: { limit: 10_000 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body.length).to be <= 500
    end
  end
end
