class CreateRules < ActiveRecord::Migration[8.0]
  def change
    create_table :rules do |t|
      t.string :name, null: false
      t.string :condition_type, null: false # 'description_contains', 'amount_greater_than', 'amount_less_than', 'amount_equals'
      t.string :condition_value, null: false
      t.string :action_type, null: false # 'categorize', 'flag'
      t.string :action_value
      t.references :category, foreign_key: true
      t.boolean :active, default: true, null: false
      t.integer :priority, default: 0

      t.timestamps
    end

    add_index :rules, :active
    add_index :rules, [:active, :priority]
  end
end
