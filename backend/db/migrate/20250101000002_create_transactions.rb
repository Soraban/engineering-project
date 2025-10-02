class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.date :transaction_date, null: false
      t.text :description
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.references :category, foreign_key: true
      t.boolean :reviewed, default: false, null: false
      t.boolean :flagged_as_anomaly, default: false, null: false
      t.string :anomaly_reason
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # Performance indexes
    add_index :transactions, :transaction_date
    add_index :transactions, :amount
    add_index :transactions, :category_id
    add_index :transactions, :reviewed
    add_index :transactions, :flagged_as_anomaly
    add_index :transactions, :created_at

    # Composite indexes for common queries
    add_index :transactions, [:reviewed, :flagged_as_anomaly]
    add_index :transactions, [:transaction_date, :amount]

    # GIN index for jsonb metadata search
    add_index :transactions, :metadata, using: :gin
  end
end
