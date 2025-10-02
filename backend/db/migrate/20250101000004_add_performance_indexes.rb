class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Composite index for dashboard queries (reviewed + category filtering)
    add_index :transactions, [:reviewed, :category_id], name: 'idx_transactions_review_category'

    # Composite index for anomaly detection (duplicate detection)
    add_index :transactions, [:transaction_date, :amount], name: 'idx_transactions_date_amount'

    # Functional index for case-insensitive description matching
    add_index :transactions, 'LOWER(description)', name: 'idx_transactions_description_lower'

    # Partial indexes for common filters (reduces index size significantly)
    add_index :transactions, :id, where: "category_id IS NULL", name: 'idx_uncategorized'
    add_index :transactions, :id, where: "flagged_as_anomaly = true", name: 'idx_flagged'
    add_index :transactions, :id, where: "reviewed = false AND (flagged_as_anomaly = true OR category_id IS NULL)", name: 'idx_needs_review'

    # Index for time-based queries (recent transactions)
    add_index :transactions, [:created_at, :transaction_date], name: 'idx_transactions_created_at_date'

    # Composite index for rule matching
    add_index :rules, [:active, :priority], order: { priority: :desc }, name: 'idx_rules_active_priority'
  end
end
