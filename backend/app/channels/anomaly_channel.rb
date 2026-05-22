# Per-user broadcast channel for real-time anomaly notifications.
# Frontend subscribes when mounting the Dashboard; AnomalyDetector
# broadcasts to it whenever a new anomaly is created so the UI can
# refresh without a full page reload.
class AnomalyChannel < ApplicationCable::Channel
  def subscribed
    stream_from "anomalies_for_user_#{params[:user_id]}"
  end

  def unsubscribed
    stop_all_streams
  end
end
