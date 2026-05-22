class CreateTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date, null: false
      t.text :description
      t.text :description_normalized
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :category, limit: 100
      t.string :status, limit: 50, default: 'pending'
      t.string :source, limit: 20, default: 'manual'
      t.jsonb :anomaly_flags, default: []
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :transactions, [:user_id, :date], order: { date: :desc }, name: 'idx_transactions_user_date'
    add_index :transactions, [:user_id, :status], where: "status != 'reviewed'", name: 'idx_transactions_status'
    add_index :transactions, [:user_id, :category], name: 'idx_transactions_category'
    add_index :transactions, [:user_id, :amount], name: 'idx_transactions_amount'
    add_index :transactions, [:user_id, :date, :amount, :description_normalized], name: 'idx_transactions_duplicate_check'

    reversible do |dir|
      dir.up do
        execute <<-SQL
          CREATE INDEX idx_transactions_description_gin ON transactions USING gin(to_tsvector('english', coalesce(description, '')));
        SQL
      end
      dir.down do
        execute "DROP INDEX IF EXISTS idx_transactions_description_gin;"
      end
    end
  end
end
