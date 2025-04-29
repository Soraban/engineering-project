class AddPriorityToRules < ActiveRecord::Migration[7.0]
  def change
    add_column :rules, :priority, :integer, default: 0, null: false
  end
end 