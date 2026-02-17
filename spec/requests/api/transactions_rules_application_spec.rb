require "rails_helper"

RSpec.describe "Transaction rule application", type: :request do
  it "applies description_contains rules when creating a transaction" do
    CategorizationRule.create!(
      kind: "description_contains",
      pattern: "amazon",
      category: "Shopping",
      active: true
    )

    post "/api/transactions", params: {
      transaction: {
        date: Date.current,
        description: "Amazon Prime",
        amount: "10.00",
        category: ""
      }
    }

    expect(response).to have_http_status(:created)
    json = JSON.parse(response.body)
    expect(json["category"]).to eq("Shopping")
  end

  it "flags high value transactions during CSV import" do
    CategorizationRule.create!(
      kind: "amount_greater_than",
      min_amount: "1000.00",
      active: true
    )

    csv = <<~CSV
      date,description,amount,category
      2026-02-16,Rent,1500.00,
    CSV

    file = Tempfile.new([ "transactions", ".csv" ])
    file.write(csv)
    file.rewind

    post "/api/transactions/import", params: { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }

    expect(response).to have_http_status(:ok)

    tx = Transaction.order(created_at: :desc).first
    expect(tx.flagged).to eq(true)
    expect(tx.flag_reason).to eq("High Value")
  ensure
    file.close
    file.unlink
  end
end
