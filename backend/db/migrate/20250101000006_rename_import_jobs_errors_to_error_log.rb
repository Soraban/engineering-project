class RenameImportJobsErrorsToErrorLog < ActiveRecord::Migration[8.0]
  def change
    rename_column :import_jobs, :errors, :error_log
  end
end
