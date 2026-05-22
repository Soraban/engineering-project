import { useState, useCallback, useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { useAnomalyNotifications } from '../hooks/useWebSocket'

interface Toast {
  id: number
  anomaly_type: string
  severity: string
  transaction_id: number
  createdAt: number
}

const AUTO_DISMISS_MS = 8000
const SEVERITY_COLORS: Record<string, string> = {
  high: 'var(--red)',
  medium: 'var(--amber)',
  low: 'var(--text3)',
}

function anomalyLabel(type: string): string {
  switch (type) {
    case 'missing_metadata': return 'Missing Info'
    case 'unusual_amount':   return 'Unusual Amount'
    case 'potential_duplicate': return 'Possible Duplicate'
    case 'high_value':       return 'High Value'
    default:                 return type.replace(/_/g, ' ')
  }
}

export default function NotificationToaster() {
  const [toasts, setToasts] = useState<Toast[]>([])
  const queryClient = useQueryClient()
  const navigate = useNavigate()

  const handleNotification = useCallback((n: { anomaly_type: string; severity: string; transaction_id: number }) => {
    const id = Date.now() + Math.random()
    setToasts(prev => [...prev, { id, ...n, createdAt: Date.now() }])
    // Invalidate so any open Dashboard refetches and shows the new flag.
    queryClient.invalidateQueries({ queryKey: ['dashboard'] })
  }, [queryClient])

  useAnomalyNotifications(handleNotification)

  // Auto-dismiss expired toasts every second
  useEffect(() => {
    if (toasts.length === 0) return
    const interval = setInterval(() => {
      const now = Date.now()
      setToasts(prev => prev.filter(t => now - t.createdAt < AUTO_DISMISS_MS))
    }, 500)
    return () => clearInterval(interval)
  }, [toasts.length])

  const dismiss = (id: number) => setToasts(prev => prev.filter(t => t.id !== id))

  const view = (txId: number, id: number) => {
    dismiss(id)
    navigate(`/transactions?id=${txId}`)
  }

  if (toasts.length === 0) return null

  return (
    <div className="toaster">
      {toasts.map(t => (
        <div
          key={t.id}
          className="toast"
          style={{ borderLeftColor: SEVERITY_COLORS[t.severity] ?? 'var(--text3)' }}
        >
          <div className="toast-body">
            <div className="toast-title">
              New anomaly · <span className="toast-severity">{t.severity}</span>
            </div>
            <div className="toast-detail">
              {anomalyLabel(t.anomaly_type)} on transaction <strong>#{t.transaction_id}</strong>
            </div>
          </div>
          <div className="toast-actions">
            <button className="toast-link" onClick={() => view(t.transaction_id, t.id)}>View</button>
            <button className="toast-close" onClick={() => dismiss(t.id)} aria-label="Dismiss">✕</button>
          </div>
        </div>
      ))}
    </div>
  )
}
