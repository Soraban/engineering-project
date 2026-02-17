class AllowNullPatternAndCategoryOnCategorizationRules < ActiveRecord::Migration[8.0]
  def change
    change_column_null :categorization_rules, :pattern, true
    change_column_null :categorization_rules, :category, true
  end
end
