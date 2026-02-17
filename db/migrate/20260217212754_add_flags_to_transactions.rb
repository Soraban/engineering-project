class AddFlagsToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :flagged, :boolean, null: false, default: false
    add_column :transactions, :flag_reason, :string
  end
end
