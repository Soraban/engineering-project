class CreateAnomalyFlags < ActiveRecord::Migration[8.0]
  def change
    create_table :anomaly_flags do |t|
      t.integer :transaction_id, null: false
      t.integer :anomaly_type, null: false, default: 0  # enum
      t.integer :severity, null: false, default: 1      # enum: low=0, medium=1, high=2, critical=3
      t.json :details
      t.boolean :resolved, default: false

      t.timestamps
    end

    add_index :anomaly_flags, :transaction_id
    add_index :anomaly_flags, :resolved
    add_index :anomaly_flags, :anomaly_type
    add_index :anomaly_flags, [:resolved, :severity]
  end
end
