class Api::V1::AnomaliesController < Api::V1::BaseController
  def index
    anomalies = Anomaly.joins(:bookkeeping_transaction)
                       .where(transactions: { user_id: current_user.id })
                       .includes(:bookkeeping_transaction)
                       .order(created_at: :desc)

    anomalies = anomalies.unresolved if params[:unresolved] == 'true'

    render json: AnomalySerializer.render_as_json(anomalies)
  end

  def update
    anomaly = find_anomaly
    if anomaly.update(anomaly_params)
      render json: AnomalySerializer.render_as_json(anomaly)
    else
      render_error(anomaly.errors.full_messages)
    end
  end

  def resolve
    anomaly = find_anomaly
    anomaly.update!(resolved: true, resolved_at: Time.current)
    render json: AnomalySerializer.render_as_json(anomaly)
  end

  private

  def find_anomaly
    Anomaly.joins(:bookkeeping_transaction)
           .where(transactions: { user_id: current_user.id })
           .find(params[:id])
  end

  def anomaly_params
    params.require(:anomaly).permit(:resolved)
  end
end
