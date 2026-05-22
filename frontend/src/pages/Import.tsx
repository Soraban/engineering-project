import { useState, useCallback, useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import CSVDropzone from '../components/CSVDropzone'
import TransactionForm from '../components/TransactionForm'
import { uploadCSV, updateTransaction, deleteTransaction, fetchTransaction } from '../api/client'
import { useImportProgress } from '../hooks/useWebSocket'
import { useConfirm } from '../hooks/useConfirm'
import type { Transaction, NeedsAttentionRow } from '../types'
import AnomalyBadge from '../components/AnomalyBadge'

interface CompleteResult {
  imported: number
  errors: number
  flagged: number
  error_details: string[]
  preview: NeedsAttentionRow[]
  preview_limit: number
}

export default function Import() {
  const [importId, setImportId] = useState<string | null>(null)
  const [pendingFile, setPendingFile] = useState<File | null>(null)
  const [uploading, setUploading] = useState(false)
  const [result, setResult] = useState<CompleteResult | null>(null)
  const [previewRows, setPreviewRows] = useState<NeedsAttentionRow[]>([])
  const [editingTx, setEditingTx] = useState<Transaction | null>(null)
  const [error, setError] = useState('')
  const queryClient = useQueryClient()
  const { confirm, dialog: confirmDialog } = useConfirm()

  const { progress, subscribed } = useImportProgress(importId)

  const handleFile = (file: File) => {
    setUploading(true)
    setError('')
    setResult(null)
    setPreviewRows([])
    // Generate the import_id client-side and set it BEFORE uploading. The
    // useImportProgress hook will open and subscribe its WebSocket while the
    // upload is in flight; we then wait for `subscribed === true` before
    // actually POSTing the file, so the broadcast can't beat the subscription.
    const newImportId = crypto.randomUUID()
    setImportId(newImportId)
    setPendingFile(file)
  }

  // Once the WebSocket has confirmed its subscription to ImportStatusChannel,
  // it's safe to upload — any 'complete' broadcast will reach us.
  useEffect(() => {
    if (!subscribed || !pendingFile || !importId) return
    const file = pendingFile
    setPendingFile(null) // single-shot
    uploadCSV(file, importId).catch(() => {
      setError('Upload failed. Please try again.')
      setUploading(false)
      setImportId(null)
    })
  }, [subscribed, pendingFile, importId])

  // When the broadcast tells us the import is done, snapshot the result and
  // imported rows. Tied to importId in the deps so a new upload guarantees
  // a re-run; tied to !result so we don't re-snapshot mid-render after we
  // already captured it.
  useEffect(() => {
    if (progress?.status === 'complete' && !result) {
      setResult({
        imported: progress.imported!,
        errors: progress.errors!,
        flagged: progress.flagged!,
        error_details: progress.error_details ?? [],
        preview: progress.preview ?? [],
        preview_limit: progress.preview_limit ?? 50,
      })
      setPreviewRows(progress.preview ?? [])
      setUploading(false)
      queryClient.invalidateQueries({ queryKey: ['transactions'] })
      queryClient.invalidateQueries({ queryKey: ['dashboard'] })
    }
  }, [progress, result, importId, queryClient])

  const invalidateAll = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ['transactions'] })
    queryClient.invalidateQueries({ queryKey: ['dashboard'] })
  }, [queryClient])

  const handleApprove = useCallback(async (row: NeedsAttentionRow) => {
    await updateTransaction(row.id, { approve: true })
    setPreviewRows(prev => prev.filter(r => r.id !== row.id))
    invalidateAll()
  }, [invalidateAll])

  const handleDelete = useCallback(async (row: NeedsAttentionRow) => {
    const ok = await confirm({
      title: `Delete transaction #${row.id}?`,
      message: 'This will permanently remove the transaction and any anomalies attached to it.',
      confirmLabel: 'Delete',
      danger: true,
    })
    if (!ok) return
    await deleteTransaction(row.id)
    setPreviewRows(prev => prev.filter(r => r.id !== row.id))
    invalidateAll()
  }, [confirm, invalidateAll])

  const handleEditClose = useCallback(async () => {
    const editedId = editingTx?.id
    setEditingTx(null)
    invalidateAll()
    // previewRows is local state (snapshot from the import broadcast) so the
    // global query invalidations don't refresh it. Refetch just the edited
    // row and merge it back so the table reflects the change without a page
    // reload.
    if (editedId !== undefined) {
      try {
        const fresh = await fetchTransaction(editedId)
        setPreviewRows(prev => prev.map(r => r.id === editedId ? { ...r, ...fresh } : r))
      } catch {
        // If the fetch fails (e.g. row was deleted in another tab), drop it
        // from the preview rather than leave stale data on screen.
        setPreviewRows(prev => prev.filter(r => r.id !== editedId))
      }
    }
  }, [editingTx, invalidateAll])

  return (
    <>
      <div className="page-header">
        <h1 className="page-title">Import CSV</h1>
      </div>

      <CSVDropzone onFile={handleFile} disabled={uploading} />

      {uploading && progress && (
        <div style={{ marginTop: 24 }}>
          <p>Processing... {progress.processed} rows processed, {progress.imported} imported</p>
          <div className="progress-bar">
            <div className="progress-fill" style={{ width: progress.processed ? '50%' : '10%' }} />
          </div>
        </div>
      )}

      {uploading && !progress && (
        <div style={{ marginTop: 24 }}>
          <p>Uploading and processing...</p>
          <div className="progress-bar">
            <div className="progress-fill" style={{ width: '10%' }} />
          </div>
        </div>
      )}

      {error && <p className="error-text" style={{ marginTop: 16 }}>{error}</p>}

      {result && (
        <>
          <div style={{ marginTop: 24 }}>
            <div className="cards-row" style={{ gridTemplateColumns: 'repeat(3, 1fr)' }}>
              <div className="stat-card">
                <div className="label">Imported</div>
                <div className="value green">{result.imported}</div>
              </div>
              <div className="stat-card">
                <div className="label">Errors (Skipped)</div>
                <div className="value amber">{result.errors}</div>
              </div>
              <div className="stat-card">
                <div className="label">Flagged</div>
                <div className="value red">{result.flagged}</div>
              </div>
            </div>
          </div>

          {result.errors > 0 && (
            <div className="section">
              <h2 className="section-title">Skipped rows ({result.errors})</h2>
              <div className="error-panel">
                {result.error_details.map((msg, i) => (
                  <div key={i} className="error-row">{msg}</div>
                ))}
                {result.errors > result.error_details.length && (
                  <div className="error-row" style={{ color: 'var(--text3)' }}>
                    …and {result.errors - result.error_details.length} more errors not shown
                  </div>
                )}
              </div>
            </div>
          )}

          {previewRows.length > 0 && (
            <div className="section">
              <div className="section-header">
                <h2 className="section-title">
                  Imported transactions
                  {result.imported > result.preview_limit && (
                    <span style={{ fontSize: 12, fontWeight: 400, color: 'var(--text3)', marginLeft: 8 }}>
                      showing first {result.preview_limit} of {result.imported}
                    </span>
                  )}
                </h2>
              </div>
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Date</th>
                      <th>Description</th>
                      <th>Amount</th>
                      <th>Category</th>
                      <th>Status</th>
                      <th>Flags</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {previewRows.map(row => (
                      <tr key={row.id} className={row.status === 'flagged' ? 'flagged' : ''}>
                        <td style={{ color: 'var(--text3)' }}>#{row.id}</td>
                        <td style={{ whiteSpace: 'nowrap' }}>{row.date}</td>
                        <td>{row.description || <span style={{ color: 'var(--text3)' }}>(none)</span>}</td>
                        <td className="amount">${Number(row.amount).toFixed(2)}</td>
                        <td>{row.category ? <span className="badge badge-blue">{row.category}</span> : <span style={{ color: 'var(--text3)' }}>—</span>}</td>
                        <td><span className={`status-pill status-${row.status}`}>{row.status}</span></td>
                        <td>{row.anomaly_flags.map(flag => <AnomalyBadge key={flag} type={flag} />)}</td>
                        <td className="actions">
                          <button className="btn btn-sm" onClick={() => setEditingTx(row)}>Edit</button>
                          {(row.status === 'pending' || row.status === 'flagged') && (
                            <button className="btn btn-sm btn-primary" onClick={() => handleApprove(row)}>Approve</button>
                          )}
                          <button className="btn btn-sm btn-danger" onClick={() => handleDelete(row)}>Delete</button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </>
      )}

      {editingTx && (
        <>
          <div className="slide-over-backdrop" onClick={() => setEditingTx(null)} />
          <div className="slide-over">
            <h2>Edit Transaction #{editingTx.id}</h2>
            <TransactionForm transaction={editingTx} onClose={handleEditClose} />
          </div>
        </>
      )}

      {confirmDialog}
    </>
  )
}
