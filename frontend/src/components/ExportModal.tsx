import { useState, useEffect, useCallback } from 'react'
import { countTransactions, exportTransactions } from '../api/client'

const CATEGORIES = [
  'Shopping', 'Food & Dining', 'Entertainment', 'Housing', 'Transportation',
  'Utilities', 'Healthcare', 'Travel', 'Education', 'Subscriptions',
]

interface ExportModalProps {
  initialFilters?: Record<string, string>
  onClose: () => void
}

export default function ExportModal({ initialFilters = {}, onClose }: ExportModalProps) {
  const [dateFrom, setDateFrom] = useState(initialFilters.date_from ?? '')
  const [dateTo, setDateTo] = useState(initialFilters.date_to ?? '')
  const [status, setStatus] = useState(initialFilters.status ?? '')
  const [category, setCategory] = useState(initialFilters.category ?? '')

  const [count, setCount] = useState<number | null>(null)
  const [isCounting, setIsCounting] = useState(false)
  const [isExporting, setIsExporting] = useState(false)

  const buildParams = useCallback((): Record<string, string> => {
    const params: Record<string, string> = {}
    if (dateFrom) params.date_from = dateFrom
    if (dateTo) params.date_to = dateTo
    if (status) params.status = status
    if (category) params.category = category
    return params
  }, [dateFrom, dateTo, status, category])

  useEffect(() => {
    let cancelled = false
    setIsCounting(true)
    countTransactions(buildParams())
      .then(n => { if (!cancelled) setCount(n) })
      .finally(() => { if (!cancelled) setIsCounting(false) })
    return () => { cancelled = true }
  }, [buildParams])

  const handleExport = async () => {
    setIsExporting(true)
    try {
      await exportTransactions(buildParams())
      onClose()
    } finally {
      setIsExporting(false)
    }
  }

  return (
    <>
      <div className="slide-over-backdrop" onClick={onClose} />
      <div className="slide-over">
        <h2>Export Transactions</h2>

        <p style={{ fontSize: 13, color: 'var(--text2)', marginBottom: 20 }}>
          Choose filters to limit which transactions are included in the CSV. Leave a field blank to include all.
        </p>

        <div className="form-group">
          <label htmlFor="export-date-from">From date</label>
          <input id="export-date-from" type="date" value={dateFrom} onChange={e => setDateFrom(e.target.value)} />
        </div>

        <div className="form-group">
          <label htmlFor="export-date-to">To date</label>
          <input id="export-date-to" type="date" value={dateTo} onChange={e => setDateTo(e.target.value)} />
        </div>

        <div className="form-group">
          <label htmlFor="export-status">Status</label>
          <select id="export-status" value={status} onChange={e => setStatus(e.target.value)}>
            <option value="">All statuses</option>
            <option value="pending">Pending</option>
            <option value="flagged">Flagged</option>
            <option value="reviewed">Reviewed</option>
          </select>
        </div>

        <div className="form-group">
          <label htmlFor="export-category">Category</label>
          <select id="export-category" value={category} onChange={e => setCategory(e.target.value)}>
            <option value="">All categories</option>
            {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
        </div>

        <div className="export-summary">
          {isCounting && count === null
            ? 'Counting…'
            : <><strong>{count?.toLocaleString() ?? '—'}</strong> transactions will be exported</>
          }
        </div>

        <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
          <button className="btn" onClick={onClose} disabled={isExporting}>Cancel</button>
          <button
            className="btn btn-primary"
            onClick={handleExport}
            disabled={isExporting || count === 0}
            style={{ flex: 1 }}
          >
            {isExporting ? 'Exporting…' : 'Download CSV'}
          </button>
        </div>
      </div>
    </>
  )
}
