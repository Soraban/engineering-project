module Api
  module V1
    class RulesController < ::ApplicationController
      def index
        @rules = Rule.includes(:category)
        render json: @rules
      end

      def create
        @rule = Rule.new(rule_params)
        
        if @rule.save
          # When a new rule is created, schedule a background job to apply it to existing transactions
          ApplyRuleToExistingTransactionsJob.perform_later(@rule.id)
          render json: @rule, status: :created
        else
          render json: { errors: @rule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        @rule = Rule.find(params[:id])
        
        if @rule.update(rule_params)
          # When a rule is updated, apply it to existing transactions
          ApplyRuleToExistingTransactionsJob.perform_later(@rule.id)
          render json: @rule
        else
          render json: { errors: @rule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @rule = Rule.find(params[:id])
        @rule.destroy
        head :no_content
      end

      private

      def rule_params
        params.require(:rule).permit(:condition_field, :condition_operator, :condition_value, :category_id)
      end
    end
  end
end 