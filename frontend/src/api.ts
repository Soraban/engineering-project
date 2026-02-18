export type Transaction = {
  id: number
  date: string
  description: string
  amount: string
  category: string | null
  flagged: boolean
  flag_reason: string | null
  created_at: string
  updated_at: string
}

const API_BASE = import.meta.env.DEV ? "http://localhost:3000" : ""

export async function listTransactions(): Promise<Transaction[]> {
  const res = await fetch(`${API_BASE}/api/transactions`)
  if (!res.ok) throw new Error(`Failed to load transactions (${res.status})`)
  return res.json()
}

export type ImportResult = {
  created: number
  skipped_duplicates: number
  row_errors: Array<{ line: number; errors: string[] }>
}

export async function importTransactionsCsv(file: File): Promise<ImportResult> {
  const form = new FormData()
  form.append("file", file)

  const res = await fetch(`${API_BASE}/api/transactions/import`, {
    method: "POST",
    body: form,
  })

  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error(body?.errors?.join(", ") || `Import failed (${res.status})`)
  }

  return res.json()
}

export async function bulkCategorize(input: { transactionIds: number[]; category: string }): Promise<{ updated: number }> {
  const res = await fetch(`${API_BASE}/api/transactions/bulk_update`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      transaction_ids: input.transactionIds,
      category: input.category,
    }),
  })

  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error(body?.errors?.join(", ") || `Bulk update failed (${res.status})`)
  }

  return res.json()
}

export async function createTransaction(input: {
  date: string
  description: string
  amount: string
  category?: string
}): Promise<Transaction> {
  const res = await fetch(`${API_BASE}/api/transactions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ transaction: input }),
  })
  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error(body?.errors?.join(", ") || `Create failed (${res.status})`)
  }
  return res.json()
}

export type ReviewResult = {
  flagged: Transaction[]
  uncategorized: Transaction[]
}

export async function fetchReview(limit = 100): Promise<ReviewResult> {
  const res = await fetch(`${API_BASE}/api/transactions/review?limit=${limit}`)
  if (!res.ok) throw new Error(`Failed to load review (${res.status})`)
  return res.json()
}

export async function updateTransaction(
  id: number,
  input: Partial<Pick<Transaction, "date" | "description" | "amount" | "category" | "flagged">>
): Promise<Transaction> {
  const res = await fetch(`${API_BASE}/api/transactions/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ transaction: input }),
  })

  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new Error(body?.errors?.join(", ") || `Update failed (${res.status})`)
  }

  return res.json()
}

export async function deleteTransaction(id: number): Promise<void> {
  const res = await fetch(`${API_BASE}/api/transactions/${id}`, { method: "DELETE" })
  if (!res.ok) throw new Error(`Delete failed (${res.status})`)
}


