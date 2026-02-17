require "rails_helper"

RSpec.describe "Rules API", type: :request do
  it "creates a description rule" do
    post "/api/rules", params: { rule: { kind: "description_contains", pattern: "amazon", category: "Shopping", active: true } }
    expect(response).to have_http_status(:created)
  end

  it "creates an amount rule" do
    post "/api/rules", params: { rule: { kind: "amount_greater_than", min_amount: "1000.00", active: true } }
    expect(response).to have_http_status(:created)
  end
end
