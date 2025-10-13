class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.text :description
      t.string :color

      t.timestamps
    end

    add_index :categories, :name, unique: true
    
    # Add category foreign key to transactions
    add_reference :transactions, :category, foreign_key: true, index: true
  end
end
