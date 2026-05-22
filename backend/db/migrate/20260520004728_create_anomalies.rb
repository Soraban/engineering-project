class CreateAnomalies < ActiveRecord::Migration[7.2]
  def change
    create_table :anomalies do |t|
      t.references :transaction, null: false, foreign_key: { on_delete: :cascade }
      t.string :anomaly_type, limit: 100, null: false
      t.string :severity, limit: 20, default: 'medium'
      t.jsonb :details, default: {}
      t.text :explanation
      t.datetime :explanation_generated_at
      t.boolean :resolved, default: false
      t.datetime :resolved_at
      t.datetime :created_at, null: false
    end

    add_index :anomalies, [:transaction_id, :anomaly_type], name: 'idx_anomalies_transaction_type'
    add_index :anomalies, :resolved, where: "resolved = false", name: 'idx_anomalies_unresolved'
  end
end
