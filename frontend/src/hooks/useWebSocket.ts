import { useEffect, useRef, useState } from 'react'
import type { NeedsAttentionRow } from '../types'

interface ImportProgress {
  status?: string
  processed?: number
  imported?: number
  errors?: number
  flagged?: number
  error_details?: string[]
  preview?: NeedsAttentionRow[]
  preview_limit?: number
}

// Build the WebSocket URL pointing at the API service. In dev mode VITE_API_URL
// is empty, so we use the Vite proxy via window.location. In production
// VITE_API_URL is set to the API service URL, which lives on a different domain
// than the static frontend — we have to connect there explicitly.
function cableUrl(): string {
  const apiUrl = import.meta.env.VITE_API_URL as string | undefined
  if (apiUrl) {
    const host = apiUrl.replace(/^https?:\/\//, '')
    const proto = apiUrl.startsWith('https') ? 'wss' : 'ws'
    return `${proto}://${host}/cable`
  }
  const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  return `${proto}//${window.location.host}/cable`
}

interface AnomalyNotification {
  type: 'new_anomaly'
  anomaly_type: string
  severity: string
  transaction_id: number
}

/**
 * Subscribes to the per-user anomaly broadcast. Calls `onNotification`
 * every time the backend detects a new anomaly (which happens whenever
 * a transaction is created manually or via CSV import).
 *
 * Mount this on the Dashboard so it auto-refreshes when new flags
 * appear without requiring a page reload.
 */
export function useAnomalyNotifications(onNotification: (n: AnomalyNotification) => void) {
  useEffect(() => {
    const userId = localStorage.getItem('user_id')
    if (!userId) return

    const ws = new WebSocket(cableUrl())

    ws.onopen = () => {
      ws.send(JSON.stringify({
        command: 'subscribe',
        identifier: JSON.stringify({ channel: 'AnomalyChannel', user_id: userId })
      }))
    }

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data)
      if (data.type === 'ping' || data.type === 'welcome' || data.type === 'confirm_subscription') return
      if (data.message?.type === 'new_anomaly') {
        onNotification(data.message)
      }
    }

    return () => { ws.close() }
  }, [onNotification])
}

export function useImportProgress(importId: string | null) {
  // Track which import the progress / subscription belongs to. We need this
  // because when importId changes, the useEffect that resets internal state
  // runs AFTER render — so during that one render the consumer would see
  // stale progress from the previous import paired with the new importId.
  // Filtering at the boundary (returning null when the IDs don't match)
  // guarantees the consumer never gets cross-contaminated state.
  const [progressFor, setProgressFor] = useState<{ id: string | null; progress: ImportProgress | null }>({ id: null, progress: null })
  const [subscribedId, setSubscribedId] = useState<string | null>(null)
  const wsRef = useRef<WebSocket | null>(null)

  useEffect(() => {
    if (!importId) {
      setProgressFor({ id: null, progress: null })
      setSubscribedId(null)
      return
    }

    setProgressFor({ id: importId, progress: null })
    setSubscribedId(null)

    const ws = new WebSocket(cableUrl())
    wsRef.current = ws

    ws.onopen = () => {
      ws.send(JSON.stringify({
        command: 'subscribe',
        identifier: JSON.stringify({ channel: 'ImportStatusChannel', import_id: importId })
      }))
    }

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data)
      if (data.type === 'ping' || data.type === 'welcome') return
      if (data.type === 'confirm_subscription') {
        setSubscribedId(importId)
        return
      }

      const message = data.message
      if (message) {
        setProgressFor({ id: importId, progress: message })
      }
    }

    return () => {
      ws.close()
    }
  }, [importId])

  return {
    progress: progressFor.id === importId ? progressFor.progress : null,
    subscribed: subscribedId === importId,
  }
}
