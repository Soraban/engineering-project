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
