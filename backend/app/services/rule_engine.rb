class RuleEngine
  def self.apply_to_transaction(transaction)
    Rule.active.each do |rule|
      rule.apply_to(transaction)
    end
  end

  def self.apply_to_transactions(transactions)
    transactions.each do |transaction|
      apply_to_transaction(transaction)
    end
  end

  def self.bulk_categorize(transaction_ids, category_id)
    transactions = Transaction.where(id: transaction_ids)
    category = Category.find(category_id)

    transactions.update_all(
      category_id: category.id,
      reviewed: true,
      updated_at: Time.current
    )

    { updated_count: transactions.count }
  end
end
