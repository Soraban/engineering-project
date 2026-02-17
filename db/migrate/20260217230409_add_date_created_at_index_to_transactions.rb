class AddDateCreatedAtIndexToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_index :transactions, [ :date, :created_at ]
  end
end
