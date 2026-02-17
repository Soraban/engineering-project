require "rails_helper"

RSpec.describe "Transactions CSV import", type: :request do
  describe "POST /api/transactions/import" do
    it "imports valid rows and returns a summary" do
      csv = <<~CSV
        date,description,amount,category
        2026-02-16,Coffee,5.99,Food
        2026-02-16,Lunch,12.50,
      CSV

      file = Tempfile.new([ "transactions", ".csv" ])
      file.write(csv)
      file.rewind

      post "/api/transactions/import", params: { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["created"]).to eq(2)
      expect(json["row_errors"]).to eq([])
    ensure
      file.close
      file.unlink
    end

    it "returns an error when no file is uploaded" do
      post "/api/transactions/import"

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("No file uploaded")
    end

    it "returns an error for malformed csv" do
      bad_csv = "date,description,amount\n\"unclosed"

      file = Tempfile.new([ "bad", ".csv" ])
      file.write(bad_csv)
      file.rewind

      post "/api/transactions/import", params: { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Invalid CSV file")
    ensure
      file.close
      file.unlink
    end
  end
end
