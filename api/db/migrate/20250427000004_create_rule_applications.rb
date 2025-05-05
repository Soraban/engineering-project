class CreateRuleApplications < ActiveRecord::Migration[7.0]
    def change
      create_table :rule_applications do |t|
        t.references :transaction, null: false, foreign_key: true
        t.references :rule, null: false, foreign_key: true
  
        t.timestamps
      end
      
      add_index :rule_applications, [:transaction_id, :rule_id], unique: true
    end
  end