class CreateCategorizationRules < ActiveRecord::Migration[8.0]
  def change
    create_table :categorization_rules do |t|
      t.string :name, null: false
      t.integer :rule_type, null: false, default: 0  # enum: description_contains=0, amount_threshold=1, date_range=2
      t.string :pattern
      t.references :category, null: false, foreign_key: true
      t.integer :priority, default: 0
      t.boolean :active, default: true
      t.json :conditions

      t.timestamps
    end

    add_index :categorization_rules, :active
    add_index :categorization_rules, [:active, :priority]
    add_index :categorization_rules, :rule_type
  end
end
