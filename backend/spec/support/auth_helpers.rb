module AuthHelpers
  def auth_headers(user)
    post '/api/v1/auth/sign_in', params: { user: { email: user.email, password: 'password123' } }
    token = response.headers['Authorization']
    { 'Authorization' => token }
  end

  def json_body
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
