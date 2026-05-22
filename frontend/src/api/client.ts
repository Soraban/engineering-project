import axios from 'axios'

const API_URL = import.meta.env.VITE_API_URL || ''

const api = axios.create({
  baseURL: `${API_URL}/api/v1`,
  headers: { 'Content-Type': 'application/json' }
})

api.interceptors.request.use(config => {
  const token = localStorage.getItem('auth_token')
  if (token) {
    config.headers.Authorization = token
  }
  return config
})

api.interceptors.response.use(
  response => {
    const authHeader = response.headers['authorization']
    if (authHeader) {
      localStorage.setItem('auth_token', authHeader)
    }
    return response
  },
  error => {
    if (error.response?.status === 401) {
      localStorage.removeItem('auth_token')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export default api

export async function signIn(email: string, password: string) {
  const res = await api.post('/auth/sign_in', { user: { email, password } })
  if (res.data?.user?.id) localStorage.setItem('user_id', String(res.data.user.id))
  return res.data
}

export async function signUp(email: string, password: string) {
  const res = await api.post('/auth/sign_up', { user: { email, password } })
  if (res.data?.user?.id) localStorage.setItem('user_id', String(res.data.user.id))
  return res.data
}

export async function signOut() {
  await api.delete('/auth/sign_out')
  localStorage.removeItem('auth_token')
  localStorage.removeItem('user_id')
}

// Transactions
export async function fetchTransactions(params: Record<string, string | number>) {
  const res = await api.get('/transactions', { params })
  return res.data
}

export async function fetchTransaction(id: number) {
  const res = await api.get(`/transactions/${id}`)
  return res.data
}

export async function createTransaction(data: Record<string, unknown>) {
  const res = await api.post('/transactions', { transaction: data })
  return res.data
}

export async function updateTransaction(id: number, data: Record<string, unknown>) {
  const res = await api.patch(`/transactions/${id}`, { transaction: data })
  return res.data
}

export async function deleteTransaction(id: number) {
  await api.delete(`/transactions/${id}`)
}

export async function bulkAction(ids: number[], actionType: string, value?: string) {
  const res = await api.put('/transactions/bulk', { ids, action_type: actionType, value })
  return res.data
}

export async function countTransactions(params: Record<string, string> = {}): Promise<number> {
  const res = await api.get('/transactions/count', { params })
  return res.data.count
}

export async function exportTransactions(params: Record<string, string> = {}) {
  const res = await api.get('/transactions/export', { params, responseType: 'blob' })

  const disposition = (res.headers['content-disposition'] as string | undefined) ?? ''
  const filenameMatch = disposition.match(/filename="?([^";]+)"?/)
  const filename = filenameMatch?.[1] ?? `transactions-${new Date().toISOString().slice(0, 10)}.csv`

  const url = window.URL.createObjectURL(new Blob([res.data], { type: 'text/csv' }))
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  link.remove()
  window.URL.revokeObjectURL(url)
}

// Rules
export async function fetchRules() {
  const res = await api.get('/rules')
  return res.data
}

export async function createRule(data: Record<string, unknown>) {
  const res = await api.post('/rules', { rule: data })
  return res.data
}

export async function updateRule(id: number, data: Record<string, unknown>) {
  const res = await api.patch(`/rules/${id}`, { rule: data })
  return res.data
}

export async function deleteRule(id: number) {
  await api.delete(`/rules/${id}`)
}

// Anomalies
export async function fetchAnomalies(params?: Record<string, string>) {
  const res = await api.get('/anomalies', { params })
  return res.data
}

export async function resolveAnomaly(id: number) {
  const res = await api.patch(`/anomalies/${id}/resolve`)
  return res.data
}

// Dashboard
export async function fetchDashboard(params: Record<string, string | number> = {}) {
  const res = await api.get('/dashboard', { params })
  return res.data
}

// Imports
export async function uploadCSV(file: File, importId?: string) {
  const formData = new FormData()
  formData.append('file', file)
  // Pass a client-generated import_id so the frontend can subscribe to the
  // status channel BEFORE the job is enqueued. Avoids the race where small
  // CSVs finish processing before the WebSocket subscription is confirmed.
  if (importId) formData.append('import_id', importId)
  const res = await api.post('/imports', formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  })
  return res.data
}
