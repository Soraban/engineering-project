class CategorizationRulesController < ApplicationController
  before_action :set_rule, only: [:edit, :update, :destroy, :toggle]

  def index
    @rules = CategorizationRule.includes(:category).ordered.page(params[:page]).per(20)
  end

  def new
    @rule = CategorizationRule.new
    @categories = Category.ordered
  end

  def create
    @rule = CategorizationRule.new(rule_params)

    if @rule.save
      redirect_to categorization_rules_path, notice: 'Rule was successfully created.'
    else
      @categories = Category.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = Category.ordered
  end

  def update
    if @rule.update(rule_params)
      redirect_to categorization_rules_path, notice: 'Rule was successfully updated.'
    else
      @categories = Category.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rule.destroy
    redirect_to categorization_rules_path, notice: 'Rule was successfully deleted.'
  end

  def apply
    if params[:id]
      # Apply single rule
      rule = CategorizationRule.find(params[:id])
      count = rule.apply_to_transactions
      flash[:notice] = "Rule applied to #{count} transaction(s)."
    else
      # Apply all rules
      CategorizationRule.apply_all_rules
      flash[:notice] = 'All rules applied successfully.'
    end

    redirect_to categorization_rules_path
  end

  def toggle
    @rule.update(active: !@rule.active)
    redirect_to categorization_rules_path, notice: "Rule #{@rule.active? ? 'activated' : 'deactivated'}."
  end

  private

  def set_rule
    @rule = CategorizationRule.find(params[:id])
  end

  def rule_params
    params.require(:categorization_rule).permit(
      :name, :rule_type, :pattern, :category_id, :priority, :active, 
      conditions: {}
    )
  end
end
