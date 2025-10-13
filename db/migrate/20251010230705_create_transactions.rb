class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.date :date, null: false
      t.text :description
      t.string :description_hash, limit: 64  # SHA-256 hexdigest (always 64 chars)
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.integer :status, default: 0, null: false  # enum: pending=0, approved=1, reviewed=2, flagged=3
      t.boolean :flagged, default: false

      t.timestamps
    end

    # Performance indexes for common queries
    add_index :transactions, :date          # Filtering and sorting by date
    add_index :transactions, :flagged       # Filtering flagged transactions
    add_index :transactions, :created_at    # Sorting by creation time
    
    # Composite index for duplicate detection (critical for performance)
    add_index :transactions, [:date, :amount, :description_hash], 
              name: 'idx_transactions_duplicate_check'
    
    # Composite index for anomaly detection (rapid transaction pattern detection)
    add_index :transactions, [:date, :amount], 
              name: 'idx_transactions_date_amount'
  end
end
