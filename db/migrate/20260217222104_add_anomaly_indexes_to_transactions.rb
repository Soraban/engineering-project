class AddAnomalyIndexesToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_index :transactions, :flagged
    add_index :transactions, :category
    add_index :transactions, [ :date, :amount, :description ], name: "idx_transactions_dedupe"
  end
end
