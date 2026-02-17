class AddKindAndMinAmountToCategorizationRules < ActiveRecord::Migration[8.0]
  def change
    add_column :categorization_rules, :kind, :string, null: false
    add_column :categorization_rules, :min_amount, :decimal, precision: 12, scale: 2
  end
end
