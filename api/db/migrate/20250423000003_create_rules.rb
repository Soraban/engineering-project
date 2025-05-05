class CreateRules < ActiveRecord::Migration[6.1]
    def change
      create_table :rules do |t|
        t.string :condition_field, null: false
        t.string :condition_operator, null: false
        t.string :condition_value, null: false
        t.references :category, null: false, foreign_key: true
        t.timestamps
      end
    end
  end