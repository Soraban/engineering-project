require 'rails_helper'

RSpec.describe 'POST /api/v1/imports', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it 'accepts a valid CSV and enqueues a job' do
    csv = Rack::Test::UploadedFile.new(
      Rails.root.join('spec/fixtures/files/valid_transactions.csv'),
      'text/csv'
    )

    expect {
      post '/api/v1/imports', params: { file: csv }
    }.to have_enqueued_job(CsvImportJob)

    expect(response).to have_http_status(:accepted)
    expect(json_body['import_id']).to be_present
  end

  it 'enqueues the job with the CSV content (string), not a tempfile path' do
    # Regression: Sidekiq runs in a separate container on Render and cannot
    # read tempfiles from the web container. Job arg #2 must be the file
    # CONTENTS, not a /tmp/* path.
    csv = Rack::Test::UploadedFile.new(
      Rails.root.join('spec/fixtures/files/valid_transactions.csv'),
      'text/csv'
    )

    expect {
      post '/api/v1/imports', params: { file: csv }
    }.to have_enqueued_job(CsvImportJob).with { |_user_id, second_arg, _import_id|
      expect(second_arg).to be_a(String)
      expect(second_arg).to include('Amazon Purchase') # known content of the fixture
      expect(second_arg).not_to start_with('/tmp/')
    }
  end

  it 'rejects non-CSV files' do
    # Create a temp PDF-like file
    file = Rack::Test::UploadedFile.new(
      StringIO.new('%PDF-1.4 fake pdf'),
      'application/pdf',
      true,
      original_filename: 'document.pdf'
    )

    post '/api/v1/imports', params: { file: file }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects request without file' do
    post '/api/v1/imports', params: {}
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'uses the client-provided import_id when present' do
    # The frontend generates the UUID so it can subscribe to the status
    # channel before the job runs (avoids a broadcast/subscribe race).
    csv = Rack::Test::UploadedFile.new(
      Rails.root.join('spec/fixtures/files/valid_transactions.csv'),
      'text/csv'
    )
    client_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'

    post '/api/v1/imports', params: { file: csv, import_id: client_id }

    expect(json_body['import_id']).to eq(client_id)
  end
end
