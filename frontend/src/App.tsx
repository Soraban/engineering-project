import { useEffect, useState } from "react"
import { bulkCategorize, createTransaction, listTransactions, importTransactionsCsv, type Transaction, type ImportResult } from "./api"
import { formatCurrency } from "./utils/money"
import "./App.css"

export default function App() {
  const [transactions, setTransactions] = useState<Transaction[]>([])
  const [importResult, setImportResult] = useState<ImportResult | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [csvFile, setCsvFile] = useState<File | null>(null)
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set())
  const [bulkCategory, setBulkCategory] = useState("")
  const [bulkUpdating, setBulkUpdating] = useState(false)

  const [date, setDate] = useState("")
  const [description, setDescription] = useState("")
  const [amount, setAmount] = useState("")
  const [category, setCategory] = useState("")
  const [importing, setImporting] = useState(false)

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

  function toggleSelected(id: number) {
    setSelectedIds((prev) => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }
  
  function clearSelection() {
    setSelectedIds(new Set())
  }
  
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

  async function onImport(e: React.FormEvent) {
    e.preventDefault()
    if (!csvFile) return
  
    setError(null)
    setImportResult(null)
    setImporting(true)
  
    try {
      const result = await importTransactionsCsv(csvFile)
      setImportResult(result)
      setCsvFile(null)
      await refresh()
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error")
    } finally {
      setImporting(false)
    }
  }

  async function onBulkCategorize(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
  
    const ids = Array.from(selectedIds)
    if (ids.length === 0) {
      setError("No transactions selected")
      return
    }
  
    const category = bulkCategory.trim()
    if (category.length === 0) {
      setError("Category is required")
      return
    }
  
    setBulkUpdating(true)
    try {
      await bulkCategorize({ transactionIds: ids, category })
      setBulkCategory("")
      clearSelection()
      await refresh()
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error")
    } finally {
      setBulkUpdating(false)
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
        <h2>Import CSV</h2>

        <form onSubmit={onImport}>
          <div className="formGrid" style={{ gridTemplateColumns: "2fr 1fr" }}>
            <label className="label">
              CSV file (headers: date, description, amount, category)
              <input
                className="input"
                type="file"
                accept=".csv,text/csv"
                onChange={(e) => setCsvFile(e.target.files?.[0] ?? null)}
              />
            </label>

            <div className="actions" style={{ marginTop: 0, alignSelf: "end" }}>
              <button className="button" type="submit" disabled={!csvFile || importing}>
                {importing ? "Importing…" : "Import"}
              </button>
            </div>
          </div>
        </form>

        {importResult && (
          <div style={{ marginTop: 12 }}>
            <p>
              Imported <strong>{importResult.created}</strong> transactions.{" "}
              Skipped <strong>{importResult.skipped_duplicates}</strong> duplicates.{" "}
              <strong>{importResult.row_errors.length}</strong> rows had errors.
            </p>

            {importResult.row_errors.length > 0 && (
              <>
                <p className="error">
                  {importResult.row_errors.length} row(s) had errors:
                </p>
                <ul>
                  {importResult.row_errors.slice(0, 5).map((re) => (
                    <li key={re.line}>
                      Line {re.line}: {re.errors.join(", ")}
                    </li>
                  ))}
                </ul>
              </>
            )}
          </div>
        )}
      </section>

      <section className="card">
        <h2>Bulk categorize</h2>

        <form onSubmit={onBulkCategorize}>
          <div className="formGrid" style={{ gridTemplateColumns: "2fr 1fr" }}>
            <label className="label">
              Category for selected ({selectedIds.size})
              <input
                className="input"
                value={bulkCategory}
                onChange={(e) => setBulkCategory(e.target.value)}
                placeholder="Food"
              />
            </label>

            <div className="actions" style={{ marginTop: 0, alignSelf: "end" }}>
              <button className="button" type="submit" disabled={bulkUpdating || selectedIds.size === 0}>
                {bulkUpdating ? "Applying…" : "Apply"}
              </button>
            </div>
          </div>
        </form>
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
                <th style={{ width: "1%" }}></th>
                <th align="left">Date</th>
                <th align="left">Description</th>
                <th align="right">Amount</th>
                <th align="left">Category</th>
              </tr>
            </thead>
            <tbody>
              {transactions.map((t) => (
                <tr key={t.id}>
                  <td>
                    <input
                      type="checkbox"
                      checked={selectedIds.has(t.id)}
                      onChange={() => toggleSelected(t.id)}
                    />
                  </td>
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
