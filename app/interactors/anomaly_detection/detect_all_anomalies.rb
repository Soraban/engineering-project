module AnomalyDetection
  class DetectAllAnomalies
    include Interactor::Organizer

    organize DetectUnusualAmount,
             DetectPotentialDuplicate,
             DetectMissingMetadata,
             DetectSuspiciousPattern

    # Initialize flags array
    before do
      context.flags = []
    end

    # After running all detections, collect flags and update transaction
    after do
      transaction = context.transaction
      
      # Collect any flags that were created
      flags = AnomalyFlag.where(transaction_id: transaction.id, resolved: false)
      context.flags = flags.to_a
      
      # Flag the transaction if any anomalies were found
      if flags.any?
        transaction.update_column(:flagged, true)
      end
    end
  end
end

