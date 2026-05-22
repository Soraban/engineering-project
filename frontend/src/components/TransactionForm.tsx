import { useForm } from 'react-hook-form'
import { useCreateTransaction, useUpdateTransaction } from '../hooks/useTransactions'
import type { Transaction } from '../types'

interface Props {
  transaction?: Transaction | null  // omit / null = create mode; provided = edit mode
  onClose: () => void
}

interface FormData {
  date: string
  description: string
  amount: string
  category: string
  status: 'pending' | 'flagged' | 'reviewed'
}

const CATEGORIES = ['Shopping', 'Food & Dining', 'Entertainment', 'Housing', 'Transportation', 'Utilities', 'Healthcare', 'Travel', 'Education', 'Subscriptions']

export default function TransactionForm({ transaction, onClose }: Props) {
  const isEdit = !!transaction

  const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
    defaultValues: {
      date: transaction?.date ?? new Date().toISOString().split('T')[0],
      description: transaction?.description ?? '',
      amount: transaction ? String(transaction.amount) : '',
      category: transaction?.category ?? '',
      status: transaction?.status ?? 'pending',
    },
  })

  const createMutation = useCreateTransaction()
  const updateMutation = useUpdateTransaction()
  const pending = createMutation.isPending || updateMutation.isPending

  const onSubmit = (data: FormData) => {
    const payload: Record<string, unknown> = {
      date: data.date,
      description: data.description,
      amount: parseFloat(data.amount),
      category: data.category || null,
    }

    // Only send status when it actually changed (avoids triggering a no-op
    // state-machine call on every edit).
    if (isEdit && transaction && data.status !== transaction.status) {
      payload.status = data.status
    }

    if (isEdit && transaction) {
      updateMutation.mutate({ id: transaction.id, data: payload }, { onSuccess: onClose })
    } else {
      createMutation.mutate(payload, { onSuccess: onClose })
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <div className="form-group">
        <label htmlFor="tf-date">Date</label>
        <input id="tf-date" type="date" {...register('date', { required: true })} />
        {errors.date && <p className="error-text">Date is required</p>}
      </div>
      <div className="form-group">
        <label htmlFor="tf-description">Description</label>
        <input id="tf-description" {...register('description')} placeholder="e.g. Amazon Purchase" />
      </div>
      <div className="form-group">
        <label htmlFor="tf-amount">Amount</label>
        <input id="tf-amount" type="number" step="0.01" {...register('amount', { required: true })} placeholder="0.00" />
        {errors.amount && <p className="error-text">Amount is required</p>}
      </div>
      <div className="form-group">
        <label htmlFor="tf-category">Category</label>
        <select id="tf-category" {...register('category')}>
          <option value="">None</option>
          {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
      </div>

      {isEdit && (
        <div className="form-group">
          <label htmlFor="tf-status">Status</label>
          <select id="tf-status" {...register('status')}>
            <option value="pending">Pending</option>
            <option value="flagged">Flagged</option>
            <option value="reviewed">Reviewed</option>
          </select>
          <span className="form-help">Switching back to Pending undoes an accidental approval. Every change is recorded in the audit trail.</span>
        </div>
      )}

      <div style={{ display: 'flex', gap: 8, marginTop: 20 }}>
        <button type="submit" className="btn btn-primary" disabled={pending}>
          {pending ? 'Saving…' : isEdit ? 'Save Changes' : 'Create Transaction'}
        </button>
        <button type="button" className="btn" onClick={onClose}>Cancel</button>
      </div>
    </form>
  )
}
