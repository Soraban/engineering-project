module Api
  class RulesController < ApplicationController
    def index
      render json: CategorizationRule.order(created_at: :desc), status: :ok
    end

    def create
      rule = CategorizationRule.new(rule_params)

      if rule.save
        render json: rule, status: :created
      else
        render json: { errors: rule.errors.full_messages }, status: :unprocessable_content
      end
    end

    private

    def rule_params
      params.require(:rule).permit(:kind, :pattern, :category, :min_amount, :active)
    end
  end
end
