import { useState } from 'react'
import { useBulkAction } from '../hooks/useTransactions'

interface Props {
  selectedIds: number[]
  onApply: () => void
}

const CATEGORIES = ['Shopping', 'Food & Dining', 'Entertainment', 'Housing', 'Transportation', 'Utilities', 'Healthcare', 'Travel', 'Education', 'Subscriptions']

export default function BulkActionBar({ selectedIds, onApply }: Props) {
  const [category, setCategory] = useState('')
  const bulkMutation = useBulkAction()

  const handleApply = () => {
    if (!category) return
    bulkMutation.mutate(
      { ids: selectedIds, actionType: 'set_category', value: category },
      { onSuccess: onApply }
    )
  }

  return (
    <div className={`bulk-bar ${selectedIds.length === 0 ? 'hidden' : ''}`}>
      <span>{selectedIds.length} selected</span>
      <select value={category} onChange={e => setCategory(e.target.value)} aria-label="Category">
        <option value="">Categorize as...</option>
        {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
      </select>
      <button className="btn" onClick={handleApply} disabled={!category}>Apply</button>
    </div>
  )
}
