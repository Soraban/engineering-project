class CreateTransactionTransitions < ActiveRecord::Migration[7.2]
  def change
    create_table :transaction_transitions do |t|
      t.string :to_state, null: false
      t.jsonb :metadata, default: {}
      t.integer :sort_key, null: false
      t.references :transaction, null: false, foreign_key: true
      t.boolean :most_recent, null: false

      t.timestamps null: false
    end

    add_index :transaction_transitions,
              [:transaction_id, :sort_key],
              unique: true,
              name: 'idx_tt_transaction_sort_key'
    add_index :transaction_transitions,
              [:transaction_id, :most_recent],
              unique: true,
              where: 'most_recent',
              name: 'idx_tt_transaction_most_recent'
  end
end
