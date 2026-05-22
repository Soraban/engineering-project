class AnthropicClient
  API_URL = 'https://api.anthropic.com/v1/messages'.freeze
  MODEL   = 'claude-sonnet-4-5'.freeze

  def self.explain_anomaly(context)
    prompt = build_prompt(context)
    api_key = Rails.application.credentials.anthropic_api_key || ENV['ANTHROPIC_API_KEY']

    response = HTTP.headers(
      'x-api-key'         => api_key,
      'anthropic-version' => '2023-06-01',
      'content-type'      => 'application/json'
    ).timeout(30).post(API_URL, json: {
      model:      MODEL,
      max_tokens: 50,
      messages:   [{ role: 'user', content: prompt }]
    })

    body = JSON.parse(response.body.to_s)
    body.dig('content', 0, 'text')&.strip
  rescue => e
    Rails.logger.error("AnthropicClient error: #{e.message}")
    nil
  end

  def self.build_prompt(ctx)
    <<~PROMPT
      A transaction was flagged as suspicious. Write ONE sentence, under 20 words,
      explaining why it's flagged AND what to check. Be terse. No padding, no
      preamble, no "the bookkeeper should..." — just the facts.

      Examples of the style I want:
      - "Identical $49.99 Amazon charge on the same date as transaction #482 — possible duplicate."
      - "$8,500 is 12 std devs above your $52 average; verify vendor and authorization."
      - "Missing description on a $6,002 round-number payment — likely needs an invoice attached."

      Transaction:
      - Date: #{ctx[:transaction_date]}
      - Description: #{ctx[:transaction_desc]}
      - Amount: $#{ctx[:transaction_amount]}
      - Flag: #{ctx[:anomaly_type]} (#{ctx[:severity]})
      - Stats: #{ctx[:details].to_json}

      Reply with the one sentence only.
    PROMPT
  end
end
