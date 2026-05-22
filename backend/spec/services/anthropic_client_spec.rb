require 'rails_helper'

RSpec.describe AnthropicClient do
  describe '.explain_anomaly' do
    let(:context) do
      {
        anomaly_type:       'unusual_amount',
        severity:           'high',
        transaction_date:   Date.today,
        transaction_amount: 8500.00,
        transaction_desc:   '(no description)',
        details:            { 'std_devs_above_mean' => 469.2 }
      }
    end

    it 'returns explanation string from API response' do
      stub_request(:post, 'https://api.anthropic.com/v1/messages')
        .to_return(
          status: 200,
          body: {
            content: [{ type: 'text', text: 'This transaction is unusually large.' }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = AnthropicClient.explain_anomaly(context)
      expect(result).to eq('This transaction is unusually large.')
    end

    it 'returns nil and does not raise when API call fails' do
      stub_request(:post, 'https://api.anthropic.com/v1/messages')
        .to_return(status: 500, body: 'Internal Server Error')

      expect { AnthropicClient.explain_anomaly(context) }.not_to raise_error
      expect(AnthropicClient.explain_anomaly(context)).to be_nil
    end

    it 'returns nil on network timeout' do
      stub_request(:post, 'https://api.anthropic.com/v1/messages')
        .to_timeout

      expect(AnthropicClient.explain_anomaly(context)).to be_nil
    end
  end
end
