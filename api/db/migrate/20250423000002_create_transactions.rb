class CreateTransactions < ActiveRecord::Migration[6.1]
    def change
      create_table :transactions do |t|
        t.date :date, null: false
        t.string :description
        t.decimal :amount, precision: 10, scale: 2, null: false
        t.references :category, foreign_key: true
        t.boolean :flagged, default: false
        t.json :metadata, default: {}
        t.timestamps
      end
      
      add_index :transactions, :date
      add_index :transactions, :amount
      add_index :transactions, :flagged
    end
  end