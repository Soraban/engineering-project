import { useState, useCallback, useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useTransactions, useDeleteTransaction, useUpdateTransaction } from '../hooks/useTransactions'
import { useConfirm } from '../hooks/useConfirm'
import TransactionTable, { type SortField, type SortDirection } from '../components/TransactionTable'
import BulkActionBar from '../components/BulkActionBar'
import TransactionForm from '../components/TransactionForm'
import ExportModal from '../components/ExportModal'
import type { Transaction } from '../types'

export default function Transactions() {
  const [searchParams, setSearchParams] = useSearchParams()
  const idFilter = searchParams.get('id') ?? ''

  const [filters, setFilters] = useState<Record<string, string>>({})
  const [sort, setSort] = useState<SortField>('id')
  const [direction, setDirection] = useState<SortDirection>('desc')
  const [page, setPage] = useState(1)
  const [selectedIds, setSelectedIds] = useState<number[]>([])
  const [showForm, setShowForm] = useState(false)
  const [editingTx, setEditingTx] = useState<Transaction | null>(null)
  const [showExportModal, setShowExportModal] = useState(false)

  const queryFilters = useMemo(
    () => ({ ...filters, sort, direction, page, ...(idFilter ? { id: idFilter } : {}) }),
    [filters, sort, direction, page, idFilter]
  )

  const clearIdFilter = useCallback(() => {
    const next = new URLSearchParams(searchParams)
    next.delete('id')
    setSearchParams(next, { replace: true })
  }, [searchParams, setSearchParams])

  const { data, isLoading } = useTransactions(queryFilters)
  const deleteMutation = useDeleteTransaction()
  const updateMutation = useUpdateTransaction()
  const { confirm, dialog: confirmDialog } = useConfirm()

  const handleSortChange = useCallback((field: SortField) => {
    if (field === sort) {
      setDirection(d => (d === 'asc' ? 'desc' : 'asc'))
    } else {
      setSort(field)
      setDirection('desc')
    }
    setPage(1) // sort changes reset to first page
  }, [sort])

  const allTransactions = data?.transactions ?? []
  const totalPages = data?.total_pages ?? 1
  const currentPage = data?.page ?? 1

  const handleFilterChange = useCallback((key: string, value: string) => {
    setFilters(prev => {
      if (!value) {
        const next = { ...prev }
        delete next[key]
        return next
      }
      return { ...prev, [key]: value }
    })
    setPage(1) // filter change resets to first page
  }, [])

  const handleSelect = useCallback((id: number, checked: boolean) => {
    setSelectedIds(prev => checked ? [...prev, id] : prev.filter(x => x !== id))
  }, [])

  const handleSelectAll = useCallback((checked: boolean) => {
    setSelectedIds(checked ? allTransactions.map(t => t.id) : [])
  }, [allTransactions])

  const handleDelete = useCallback(async (tx: Transaction) => {
    const ok = await confirm({
      title: `Delete transaction #${tx.id}?`,
      message: 'This will permanently remove the transaction and any anomalies attached to it.',
      confirmLabel: 'Delete',
      danger: true,
    })
    if (ok) deleteMutation.mutate(tx.id)
  }, [confirm, deleteMutation])

  const handleEdit = useCallback((tx: Transaction) => {
    setEditingTx(tx)
    setShowForm(true)
  }, [])

  const handleApprove = useCallback((tx: Transaction) => {
    updateMutation.mutate({ id: tx.id, data: { approve: true } })
  }, [updateMutation])

  const handleNew = useCallback(() => {
    setEditingTx(null)
    setShowForm(true)
  }, [])

  const handleCloseForm = useCallback(() => {
    setShowForm(false)
    setEditingTx(null)
  }, [])


  return (
    <>
      <div className="page-header">
        <h1 className="page-title">Transactions</h1>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn" onClick={() => setShowExportModal(true)}>Export CSV</button>
          <button className="btn btn-primary" onClick={handleNew}>Add Transaction</button>
        </div>
      </div>

      {idFilter && (
        <div className="active-filter-chip">
          Showing transaction <strong>#{idFilter}</strong> only
          <button onClick={clearIdFilter}>Clear filter</button>
        </div>
      )}

      <div className="table-wrap">
        <div className="filters-row">
          <input
            className="filter-input" placeholder="Search..."
            onChange={e => handleFilterChange('search', e.target.value)}
          />
          <select className="filter-select" onChange={e => handleFilterChange('status', e.target.value)}>
            <option value="">All Statuses</option>
            <option value="pending">Pending</option>
            <option value="flagged">Flagged</option>
            <option value="reviewed">Reviewed</option>
          </select>
          <select className="filter-select" onChange={e => handleFilterChange('category', e.target.value)}>
            <option value="">All Categories</option>
            {['Shopping', 'Food & Dining', 'Entertainment', 'Housing', 'Transportation', 'Utilities', 'Healthcare', 'Travel', 'Education', 'Subscriptions'].map(c => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
          <input className="filter-input" type="date" onChange={e => handleFilterChange('date_from', e.target.value)} />
          <input className="filter-input" type="date" onChange={e => handleFilterChange('date_to', e.target.value)} />
        </div>

        {isLoading ? (
          <div className="empty-state">Loading transactions...</div>
        ) : (
          <TransactionTable
            transactions={allTransactions}
            selectedIds={selectedIds}
            onSelect={handleSelect}
            onSelectAll={handleSelectAll}
            onDelete={handleDelete}
            onEdit={handleEdit}
            onApprove={handleApprove}
            sort={sort}
            direction={direction}
            onSortChange={handleSortChange}
          />
        )}

        {totalPages > 1 && (
          <div className="pagination">
            <button
              className="btn btn-sm"
              onClick={() => setPage(p => Math.max(p - 1, 1))}
              disabled={currentPage <= 1}
            >
              ← Previous
            </button>
            <span className="page-indicator">
              Page <strong>{currentPage}</strong> of <strong>{totalPages}</strong>
              <span style={{ color: 'var(--text3)', marginLeft: 8 }}>({(data?.total ?? 0).toLocaleString()} total)</span>
            </span>
            <button
              className="btn btn-sm"
              onClick={() => setPage(p => Math.min(p + 1, totalPages))}
              disabled={currentPage >= totalPages}
            >
              Next →
            </button>
          </div>
        )}
      </div>

      <BulkActionBar selectedIds={selectedIds} onApply={() => setSelectedIds([])} />

      {showForm && (
        <>
          <div className="slide-over-backdrop" onClick={handleCloseForm} />
          <div className="slide-over">
            <h2>{editingTx ? `Edit Transaction #${editingTx.id}` : 'Add Transaction'}</h2>
            <TransactionForm transaction={editingTx} onClose={handleCloseForm} />
          </div>
        </>
      )}

      {showExportModal && (
        <ExportModal initialFilters={filters} onClose={() => setShowExportModal(false)} />
      )}

      {confirmDialog}
    </>
  )
}
