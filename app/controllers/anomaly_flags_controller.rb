class AnomalyFlagsController < ApplicationController
  def resolve
    @flag = AnomalyFlag.find(params[:id])
    @flag.resolve!
    
    respond_to do |format|
      format.html { redirect_back fallback_location: transaction_path(@flag.transaction_record), notice: 'Anomaly resolved.' }
      format.json { render json: { success: true, resolved: true } }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_back fallback_location: transactions_path, alert: 'Anomaly not found.' }
      format.json { render json: { success: false, error: 'Not found' }, status: :not_found }
    end
  end
end

