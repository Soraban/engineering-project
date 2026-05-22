import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { fetchDashboard, updateTransaction, deleteTransaction } from '../api/client'
import { useConfirm } from '../hooks/useConfirm'
import type { DashboardData, NeedsAttentionRow, Anomaly } from '../types'
import AnomalyBadge from '../components/AnomalyBadge'
import TransactionForm from '../components/TransactionForm'
import SpendingCharts, { type SpendingRange } from '../components/SpendingCharts'

const TRUNCATE_AT = 150
const SEVERITY_RANK: Record<string, number> = { high: 3, medium: 2, low: 1 }

type NeedsFilter = 'all' | 'anomalies' | 'high' | 'medium' | 'low' | 'uncategorized'
type SortField = 'created_at' | 'id' | 'date' | 'amount'
type SortDirection = 'asc' | 'desc'

function maxSeverity(anomalies: Anomaly[]): 'high' | 'medium' | 'low' | null {
  if (!anomalies.length) return null
  return anomalies.reduce<'high' | 'medium' | 'low' | null>((acc, a) => {
    const rank = SEVERITY_RANK[a.severity] ?? 0
    const accRank = acc ? SEVERITY_RANK[acc] : 0
    return rank > accRank ? a.severity : acc
  }, null)
}

function isUncategorized(row: NeedsAttentionRow): boolean {
  return !row.category || row.category === ''
}

export default function Dashboard() {
  const queryClient = useQueryClient()
  const [filter, setFilter] = useState<NeedsFilter>('all')
  const [sort, setSort] = useState<SortField>('created_at')
  const [direction, setDirection] = useState<SortDirection>('desc')
  const [page, setPage] = useState(1)
  const [categoryRange, setCategoryRange] = useState<SpendingRange>('30')
  const [trendRange, setTrendRange] = useState<SpendingRange>('180')

  const { data, isLoading, isFetching, refetch } = useQuery<DashboardData>({
    queryKey: ['dashboard', filter, sort, direction, page, categoryRange, trendRange],
    queryFn: () => fetchDashboard({
      filter, sort, direction, page,
      spending_category_days: categoryRange,
      spending_trend_days: trendRange,
    }),
    // Keep the previous dashboard visible while a new fetch is in flight so
    // changing a filter / sort / range doesn't blank the whole page.
    placeholderData: (prev) => prev,
  })

  // Reset to page 1 whenever filter / sort changes
  const changeFilter = (next: NeedsFilter) => { setFilter(next); setPage(1) }
  const toggleSort = (field: SortField) => {
    if (sort !== field) { setSort(field); setDirection('desc') }
    else { setDirection(d => d === 'asc' ? 'desc' : 'asc') }
    setPage(1)
  }
  const sortIndicator = (field: SortField) => {
    if (sort !== field) return <span className="sort-indicator">↕</span>
    return <span className="sort-indicator active">{direction === 'asc' ? '↑' : '↓'}</span>
  }

  const [expandedIds, setExpandedIds] = useState<Set<number>>(new Set())
  const [editingTransaction, setEditingTransaction] = useState<NeedsAttentionRow | null>(null)
  const { confirm, dialog: confirmDialog } = useConfirm()

  const toggleExpanded = (id: number) => {
    setExpandedIds(prev => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  const rows = data?.needs_attention ?? []
  const counts = data?.needs_attention_breakdown ?? { all: 0, anomalies: 0, high: 0, medium: 0, low: 0, uncategorized: 0 }

  const invalidateAll = () => {
    queryClient.invalidateQueries({ queryKey: ['dashboard'] })
    queryClient.invalidateQueries({ queryKey: ['transactions'] })
  }

  const handleApprove = async (id: number) => {
    await updateTransaction(id, { approve: true })
    invalidateAll()
    refetch()
  }

  const handleDelete = async (row: NeedsAttentionRow) => {
    const ok = await confirm({
      title: `Delete transaction #${row.id}?`,
      message: 'This will permanently remove the transaction and any anomalies attached to it.',
      confirmLabel: 'Delete',
      danger: true,
    })
    if (!ok) return
    await deleteTransaction(row.id)
    invalidateAll()
    refetch()
  }

  if (isLoading || !data) return <div className="empty-state">Loading...</div>

  const reasonsFor = (row: NeedsAttentionRow): string[] => {
    const types = row.anomalies.map(a => a.anomaly_type)
    if (isUncategorized(row) && types.length === 0) return ['uncategorized']
    if (isUncategorized(row)) return [...types, 'uncategorized']
    return types
  }

  return (
    <>
      <div className="page-header">
        <h1 className="page-title">
          Dashboard
          {isFetching && !isLoading && <span className="refreshing-dot" aria-label="Refreshing" />}
        </h1>
      </div>

      <div className="cards-row">
        <div className="stat-card">
          <div className="label">Uncategorized</div>
          <div className="value amber">{data.uncategorized_count}</div>
        </div>
        <div className="stat-card">
          <div className="label">Flagged Anomalies</div>
          <div className="value red">{counts.anomalies}</div>
        </div>
        <div className="stat-card">
          <div className="label">Total Transactions</div>
          <div className="value">{data.total_transactions.toLocaleString()}</div>
        </div>
      </div>

      <SpendingCharts
        byCategory={data.spending_by_category}
        trend={data.spending_trend}
        trendGranularity={data.spending_trend_granularity}
        categoryRange={categoryRange}
        trendRange={trendRange}
        onCategoryRangeChange={setCategoryRange}
        onTrendRangeChange={setTrendRange}
      />

      <div className="section">
        <div className="section-header">
          <h2 className="section-title">Needs Attention</h2>
          <div className="severity-filter">
            <button className={`pill ${filter === 'all' ? 'active' : ''}`} onClick={() => changeFilter('all')}>
              All ({counts.all.toLocaleString()})
            </button>
            <button className={`pill ${filter === 'anomalies' ? 'active' : ''}`} onClick={() => changeFilter('anomalies')}>
              Anomalies ({counts.anomalies.toLocaleString()})
            </button>
            <button className={`pill pill-red ${filter === 'high' ? 'active' : ''}`} onClick={() => changeFilter('high')}>
              High ({counts.high.toLocaleString()})
            </button>
            <button className={`pill pill-amber ${filter === 'medium' ? 'active' : ''}`} onClick={() => changeFilter('medium')}>
              Medium ({counts.medium.toLocaleString()})
            </button>
            <button className={`pill pill-gray ${filter === 'low' ? 'active' : ''}`} onClick={() => changeFilter('low')}>
              Low ({counts.low.toLocaleString()})
            </button>
            <button className={`pill ${filter === 'uncategorized' ? 'active' : ''}`} onClick={() => changeFilter('uncategorized')}>
              Uncategorized ({counts.uncategorized.toLocaleString()})
            </button>
          </div>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th className="sortable" onClick={() => toggleSort('id')}>
                  Transaction {sortIndicator('id')}
                </th>
                <th className="sortable" onClick={() => toggleSort('date')}>
                  Date {sortIndicator('date')}
                </th>
                <th className="sortable" onClick={() => toggleSort('amount')}>
                  Amount {sortIndicator('amount')}
                </th>
                <th>Severity</th>
                <th>Type</th>
                <th>Explanation</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map(row => {
                const sev = maxSeverity(row.anomalies)
                const reasons = reasonsFor(row)
                const firstExplanation = row.anomalies.find(a => a.explanation)?.explanation
                return (
                  <tr key={row.id}>
                    <td>
                      <Link to={`/transactions?id=${row.id}`} className="tx-link">#{row.id}</Link>
                      <div style={{ fontSize: 12, color: 'var(--text3)', marginTop: 2 }}>
                        {row.description || '(no description)'}
                      </div>
                    </td>
                    <td style={{ whiteSpace: 'nowrap' }}>{row.date}</td>
                    <td className="amount">${Number(row.amount).toFixed(2)}</td>
                    <td>
                      {sev ? (
                        <span className={`badge badge-${sev === 'high' ? 'red' : sev === 'medium' ? 'amber' : 'gray'}`}>{sev}</span>
                      ) : (
                        <span style={{ color: 'var(--text3)' }}>—</span>
                      )}
                    </td>
                    <td>
                      {reasons.length > 0 ? (
                        reasons.map(r => <AnomalyBadge key={r} type={r} />)
                      ) : (
                        <span style={{ color: 'var(--text3)' }}>—</span>
                      )}
                    </td>
                    <td>
                      {firstExplanation ? (
                        <div className={`anomaly-explanation ${expandedIds.has(row.id) ? 'expanded' : ''}`}>
                          <p>{firstExplanation}</p>
                          {firstExplanation.length > TRUNCATE_AT && (
                            <button className="show-more-btn" onClick={() => toggleExpanded(row.id)}>
                              {expandedIds.has(row.id) ? 'Show less' : 'Show more'}
                            </button>
                          )}
                        </div>
                      ) : row.anomalies.length > 0 ? (
                        <div className="anomaly-explanation generating">
                          <p>Generating explanation...</p>
                        </div>
                      ) : (
                        <span style={{ color: 'var(--text3)' }}>Needs categorization</span>
                      )}
                    </td>
                    <td className="actions">
                      <button className="btn btn-sm" onClick={() => setEditingTransaction(row)}>Edit</button>
                      <button className="btn btn-sm btn-primary" onClick={() => handleApprove(row.id)}>Approve</button>
                      <button className="btn btn-sm btn-danger" onClick={() => handleDelete(row)}>Delete</button>
                    </td>
                  </tr>
                )
              })}
              {rows.length === 0 && (
                <tr><td colSpan={7} className="empty-state">
                  {filter === 'all' ? 'Nothing needs attention.' : `No ${filter} items.`}
                </td></tr>
              )}
            </tbody>
          </table>

          {data.needs_attention_total_pages > 1 && (
            <div className="pagination">
              <button
                className="btn btn-sm"
                onClick={() => setPage(p => Math.max(p - 1, 1))}
                disabled={page <= 1}
              >
                ← Previous
              </button>
              <span className="page-indicator">
                Page <strong>{data.needs_attention_page}</strong> of <strong>{data.needs_attention_total_pages}</strong>
                <span style={{ color: 'var(--text3)', marginLeft: 8 }}>({data.needs_attention_total.toLocaleString()} total)</span>
              </span>
              <button
                className="btn btn-sm"
                onClick={() => setPage(p => Math.min(p + 1, data.needs_attention_total_pages))}
                disabled={page >= data.needs_attention_total_pages}
              >
                Next →
              </button>
            </div>
          )}
        </div>
      </div>

      {editingTransaction && (
        <>
          <div className="slide-over-backdrop" onClick={() => setEditingTransaction(null)} />
          <div className="slide-over">
            <h2>Edit Transaction #{editingTransaction.id}</h2>
            <TransactionForm
              transaction={editingTransaction}
              onClose={() => {
                setEditingTransaction(null)
                invalidateAll()
                refetch()
              }}
            />
          </div>
        </>
      )}

      {confirmDialog}
    </>
  )
}
