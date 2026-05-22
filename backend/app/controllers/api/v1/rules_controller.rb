class Api::V1::RulesController < Api::V1::BaseController
  def index
    # Tiebreak same-priority rules by id (oldest first) so the UI list order
    # matches the order the engine evaluates them in.
    rules = current_user.rules.order(:priority, :id)
    render json: RuleSerializer.render_as_json(rules)
  end

  def show
    rule = current_user.rules.find(params[:id])
    render json: RuleSerializer.render_as_json(rule)
  end

  def create
    rule = current_user.rules.build(rule_params)
    if rule.save
      render json: RuleSerializer.render_as_json(rule), status: :created
    else
      render_error(rule.errors.full_messages)
    end
  end

  def update
    rule = current_user.rules.find(params[:id])
    if rule.update(rule_params)
      render json: RuleSerializer.render_as_json(rule)
    else
      render_error(rule.errors.full_messages)
    end
  end

  def destroy
    rule = current_user.rules.find(params[:id])
    rule.destroy!
    head :no_content
  end

  private

  def rule_params
    params.require(:rule).permit(:name, :priority, :active, :continue_processing,
                                 condition: {}, action: {})
  end
end
