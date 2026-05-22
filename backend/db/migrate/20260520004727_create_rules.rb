class CreateRules < ActiveRecord::Migration[7.2]
  def change
    create_table :rules do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, limit: 200, null: false
      t.jsonb :condition, null: false
      t.jsonb :action, null: false
      t.integer :priority, default: 0
      t.boolean :active, default: true
      t.boolean :continue_processing, default: false
      t.integer :match_count, default: 0
      t.datetime :last_matched_at
      t.decimal :match_rate, precision: 5, scale: 4
      t.timestamps
    end

    add_index :rules, [:user_id, :active, :priority], name: 'idx_rules_user_active_priority'
  end
end
