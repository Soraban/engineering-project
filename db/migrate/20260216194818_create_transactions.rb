class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.date :date, null: false
      t.text :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false # prevents rounding issues
      t.string :category

      t.timestamps
    end
  end
end
