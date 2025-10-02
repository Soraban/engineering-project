class CreateImportJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :import_jobs do |t|
      t.string :status, null: false, default: 'pending'
      t.integer :total_rows, default: 0
      t.integer :processed_rows, default: 0
      t.integer :successful_rows, default: 0
      t.integer :failed_rows, default: 0
      t.jsonb :error_log, default: []
      t.string :filename
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :import_jobs, :status
    add_index :import_jobs, :created_at
  end
end
