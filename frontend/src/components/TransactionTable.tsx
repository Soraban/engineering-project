import type { Transaction } from '../types'
import AnomalyBadge from './AnomalyBadge'

export type SortField = 'id' | 'date' | 'amount'
export type SortDirection = 'asc' | 'desc'

interface Props {
  transactions: Transaction[]
  selectedIds: number[]
  onSelect: (id: number, checked: boolean) => void
  onSelectAll: (checked: boolean) => void
  onDelete: (tx: Transaction) => void
  onEdit: (tx: Transaction) => void
  onApprove: (tx: Transaction) => void
  sort: SortField
  direction: SortDirection
  onSortChange: (field: SortField) => void
}

export default function TransactionTable({ transactions, selectedIds, onSelect, onSelectAll, onDelete, onEdit, onApprove, sort, direction, onSortChange }: Props) {
  const sortIndicator = (field: SortField) => {
    if (sort !== field) return <span className="sort-indicator">↕</span>
    return <span className="sort-indicator active">{direction === 'asc' ? '↑' : '↓'}</span>
  }

  const allSelected = transactions.length > 0 && selectedIds.length === transactions.length

  return (
    <table>
      <thead>
        <tr>
          <th style={{ width: 40 }}>
            <input type="checkbox" checked={allSelected} onChange={e => onSelectAll(e.target.checked)} />
          </th>
          <th style={{ width: 80 }}>ID</th>
          <th className="sortable" style={{ width: 110 }} onClick={() => onSortChange('date')}>
            Date {sortIndicator('date')}
          </th>
          <th>Description</th>
          <th className="sortable" style={{ width: 110 }} onClick={() => onSortChange('amount')}>
            Amount {sortIndicator('amount')}
          </th>
          <th style={{ width: 140 }}>Category</th>
          <th style={{ width: 100 }}>Status</th>
          <th style={{ width: 150 }}>Flags</th>
          <th style={{ width: 220 }}>Actions</th>
        </tr>
      </thead>
      <tbody>
        {transactions.map(tx => {
          const canApprove = tx.status === 'pending' || tx.status === 'flagged'
          return (
            <tr key={tx.id} className={tx.status === 'flagged' ? 'flagged' : ''}>
              <td>
                <input
                  type="checkbox"
                  checked={selectedIds.includes(tx.id)}
                  onChange={e => onSelect(tx.id, e.target.checked)}
                />
              </td>
              <td style={{ color: 'var(--text3)' }}>#{tx.id}</td>
              <td style={{ whiteSpace: 'nowrap' }}>{tx.date}</td>
              <td>{tx.description || <span style={{ color: 'var(--text3)' }}>(none)</span>}</td>
              <td className="amount">${Number(tx.amount).toFixed(2)}</td>
              <td>{tx.category ? <span className="badge badge-blue">{tx.category}</span> : <span style={{ color: 'var(--text3)' }}>—</span>}</td>
              <td><span className={`status-pill status-${tx.status}`}>{tx.status}</span></td>
              <td>
                {tx.anomaly_flags.map(flag => (
                  <AnomalyBadge key={flag} type={flag} />
                ))}
              </td>
              <td className="actions">
                <button className="btn btn-sm" onClick={() => onEdit(tx)}>Edit</button>
                {canApprove && (
                  <button className="btn btn-sm btn-primary" onClick={() => onApprove(tx)}>Approve</button>
                )}
                <button className="btn btn-sm btn-danger" onClick={() => onDelete(tx)}>Delete</button>
              </td>
            </tr>
          )
        })}
        {transactions.length === 0 && (
          <tr><td colSpan={9} className="empty-state">No transactions match the current filters.</td></tr>
        )}
      </tbody>
    </table>
  )
}
