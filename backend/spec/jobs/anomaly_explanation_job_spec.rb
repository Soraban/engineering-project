require 'rails_helper'

RSpec.describe AnomalyExplanationJob do
  let(:anomaly) { create(:anomaly, explanation: nil) }

  it 'stores explanation on the anomaly record' do
    allow(AnthropicClient).to receive(:explain_anomaly).and_return('This charge looks suspicious.')

    AnomalyExplanationJob.perform_now(anomaly.id)

    expect(anomaly.reload.explanation).to eq('This charge looks suspicious.')
    expect(anomaly.reload.explanation_generated_at).to be_present
  end

  it 'stores nil gracefully when API returns nil' do
    allow(AnthropicClient).to receive(:explain_anomaly).and_return(nil)

    AnomalyExplanationJob.perform_now(anomaly.id)

    expect(anomaly.reload.explanation).to be_nil
  end

  it 'does not call API if explanation already exists' do
    anomaly.update!(explanation: 'Already generated.')
    expect(AnthropicClient).not_to receive(:explain_anomaly)

    AnomalyExplanationJob.perform_now(anomaly.id)
  end

  it 'does nothing if anomaly record no longer exists' do
    expect { AnomalyExplanationJob.perform_now(999_999) }.not_to raise_error
  end
end
