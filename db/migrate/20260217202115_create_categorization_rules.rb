class CreateCategorizationRules < ActiveRecord::Migration[8.0]
  def change
    create_table :categorization_rules do |t|
      t.string :pattern, null: false
      t.string :category, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
