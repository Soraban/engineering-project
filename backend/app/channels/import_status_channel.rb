class ImportStatusChannel < ApplicationCable::Channel
  def subscribed
    stream_from "import_status_#{params[:import_id]}"
  end

  def unsubscribed
    stop_all_streams
  end
end
