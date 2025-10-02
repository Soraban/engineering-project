module Api
  module V1
    class RulesController < ApplicationController
      before_action :set_rule, only: [:show, :update, :destroy, :apply]

      # GET /api/v1/rules
      def index
        @rules = Rule.includes(:category).order(priority: :desc)
        render json: @rules.as_json(include: :category)
      end

      # GET /api/v1/rules/:id
      def show
        render json: @rule.as_json(include: :category)
      end

      # POST /api/v1/rules
      def create
        @rule = Rule.new(rule_params)

        if @rule.save
          render json: @rule.as_json(include: :category), status: :created
        else
          render json: { errors: @rule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/rules/:id
      def update
        if @rule.update(rule_params)
          render json: @rule.as_json(include: :category)
        else
          render json: { errors: @rule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/rules/:id
      def destroy
        @rule.destroy
        head :no_content
      end

      # POST /api/v1/rules/:id/apply
      def apply
        transactions = Transaction.all
        applied_count = 0

        transactions.each do |transaction|
          if @rule.matches?(transaction)
            @rule.apply_to(transaction)
            applied_count += 1
          end
        end

        render json: {
          message: "Rule applied",
          applied_count: applied_count
        }
      end

      private

      def set_rule
        @rule = Rule.find(params[:id])
      end

      def rule_params
        params.require(:rule).permit(
          :name,
          :condition_type,
          :condition_value,
          :action_type,
          :action_value,
          :category_id,
          :active,
          :priority
        )
      end
    end
  end
end
