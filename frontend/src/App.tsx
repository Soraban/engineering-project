import { useEffect, useState } from "react"
import { createTransaction, listTransactions, type Transaction } from "./api"
import { formatCurrency } from "./utils/money"
import "./App.css"

export default function App() {
  const [transactions, setTransactions] = useState<Transaction[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [date, setDate] = useState("")
  const [description, setDescription] = useState("")
  const [amount, setAmount] = useState("")
  const [category, setCategory] = useState("")

  async function refresh() {
    setError(null)
    setLoading(true)
    try {
      const data = await listTransactions()
      setTransactions(data)
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error")
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    refresh()
  }, [])

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    try {
      await createTransaction({
        date,
        description,
        amount,
        category: category.trim() === "" ? "" : category,
      })
      setDate("")
      setDescription("")
      setAmount("")
      setCategory("")
      await refresh()
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error")
    }
  }

  return (
    <div className="container">
      <h1>Bookkeeping</h1>

      <section className="card">
        <h2>Add transaction</h2>

        <form onSubmit={onSubmit}>
          <div className="formGrid">
            <label className="label">
              Date
              <input className="input" type="date" value={date} onChange={(e) => setDate(e.target.value)} required />
            </label>

            <label className="label">
              Description
              <input className="input" value={description} onChange={(e) => setDescription(e.target.value)} required />
            </label>

            <label className="label">
              Amount
              <input className="input" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="5.99" required />
            </label>

            <label className="label">
              Category (optional)
              <input className="input" value={category} onChange={(e) => setCategory(e.target.value)} placeholder="Shopping" />
            </label>
          </div>

          <div className="actions">
            <button className="button" type="submit">Create</button>
          </div>
        </form>

        {error && <p className="error">{error}</p>}
      </section>

      <section className="card">
        <h2>Transactions</h2>

        {loading ? (
          <p>Loading…</p>
        ) : transactions.length === 0 ? (
          <p>No transactions yet.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th align="left">Date</th>
                <th align="left">Description</th>
                <th align="right">Amount</th>
                <th align="left">Category</th>
              </tr>
            </thead>
            <tbody>
              {transactions.map((t) => (
                <tr key={t.id}>
                  <td className="mono">{t.date}</td>
                  <td>{t.description}</td>
                  <td className="mono" style={{ textAlign: "right" }}>{formatCurrency(t.amount)}</td>
                  <td>{t.category || ""}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  )
}
