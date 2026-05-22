class Api::V1::BaseController < ApplicationController
  before_action :authenticate_user!

  private

  def current_user_transactions
    current_user.transactions
  end

  def render_error(message, status: :unprocessable_entity)
    render json: { error: message }, status: status
  end
end
