export type Transaction = {
  id: number
  date: string
  description: string
  amount: string
  category: string | null
  created_at: string
  updated_at: string
}

export async function listTransactions(): Promise<Transaction[]> {
  const res = await fetch("/api/transactions")
  if (!res.ok) throw new Error(`Failed to load transactions (${res.status})`)
  return res.json()
}

export async function createTransaction(input: {
  date: string
  description: string
  amount: string
  category?: string
}): Promise<Transaction> {
  const res = await fetch("/api/transactions", {
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
