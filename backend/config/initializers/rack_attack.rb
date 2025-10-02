class Rack::Attack
  # Throttle all requests by IP (300 requests per 5 minutes)
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Throttle POST requests to /api/v1/transactions/import by IP (5 requests per minute)
  throttle('transactions/import/ip', limit: 5, period: 1.minute) do |req|
    if req.path == '/api/v1/transactions/import' && req.post?
      req.ip
    end
  end

  # Throttle POST requests to /api/v1/transactions by IP (60 requests per minute)
  throttle('transactions/create/ip', limit: 60, period: 1.minute) do |req|
    if req.path == '/api/v1/transactions' && req.post?
      req.ip
    end
  end

  # Block requests from specific IPs (add malicious IPs here)
  # blocklist('block suspicious IPs') do |req|
  #   ['123.456.789.0', '192.168.1.1'].include?(req.ip)
  # end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |env|
    retry_after = (env['rack.attack.match_data'] || {})[:period]
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s
      },
      [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]
    ]
  end
end
