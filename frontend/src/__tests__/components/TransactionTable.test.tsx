import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import TransactionTable from '../../components/TransactionTable'
import type { Transaction } from '../../types'

function makeTx(overrides: Partial<Transaction> = {}): Transaction {
  return {
    id: 1,
    date: '2024-06-15',
    description: 'Amazon',
    description_normalized: 'amazon',
    amount: '49.99',
    category: 'Shopping',
    status: 'pending',
    source: 'manual',
    anomaly_flags: [],
    metadata: {},
    created_at: '2024-06-15T00:00:00Z',
    updated_at: '2024-06-15T00:00:00Z',
    ...overrides,
  }
}

function renderTable(opts: { transactions?: Transaction[]; sort?: any; direction?: any } = {}) {
  const onSelect = vi.fn(), onSelectAll = vi.fn(), onDelete = vi.fn()
  const onEdit = vi.fn(), onApprove = vi.fn(), onSortChange = vi.fn()
  render(
    <TransactionTable
      transactions={opts.transactions ?? [makeTx()]}
      selectedIds={[]}
      onSelect={onSelect}
      onSelectAll={onSelectAll}
      onDelete={onDelete}
      onEdit={onEdit}
      onApprove={onApprove}
      sort={opts.sort ?? 'id'}
      direction={opts.direction ?? 'desc'}
      onSortChange={onSortChange}
    />
  )
  return { onSelect, onSelectAll, onDelete, onEdit, onApprove, onSortChange }
}

describe('TransactionTable', () => {
  describe('row rendering', () => {
    it('renders the transaction id, formatted amount, and status pill', () => {
      renderTable({ transactions: [makeTx({ id: 42, amount: '49.99', status: 'pending' })] })

      expect(screen.getByText('#42')).toBeInTheDocument()
      expect(screen.getByText('$49.99')).toBeInTheDocument()
      expect(screen.getByText('pending')).toBeInTheDocument()
    })

    it('shows "(none)" for missing description', () => {
      renderTable({ transactions: [makeTx({ description: null })] })
      expect(screen.getByText('(none)')).toBeInTheDocument()
    })

    it('shows an em-dash for missing category', () => {
      renderTable({ transactions: [makeTx({ category: null })] })
      expect(screen.getByText('—')).toBeInTheDocument()
    })

    it('shows an empty-state row when no transactions match', () => {
      renderTable({ transactions: [] })
      expect(screen.getByText(/no transactions match/i)).toBeInTheDocument()
    })
  })

  describe('Approve button visibility', () => {
    it('shows Approve when status is pending', () => {
      renderTable({ transactions: [makeTx({ status: 'pending' })] })
      expect(screen.getByRole('button', { name: /^approve$/i })).toBeInTheDocument()
    })

    it('shows Approve when status is flagged', () => {
      renderTable({ transactions: [makeTx({ status: 'flagged' })] })
      expect(screen.getByRole('button', { name: /^approve$/i })).toBeInTheDocument()
    })

    it('hides Approve when status is reviewed (already approved)', () => {
      renderTable({ transactions: [makeTx({ status: 'reviewed' })] })
      expect(screen.queryByRole('button', { name: /^approve$/i })).not.toBeInTheDocument()
    })
  })

  describe('action handlers', () => {
    it('calls onEdit with the transaction when Edit is clicked', () => {
      const tx = makeTx({ id: 7 })
      const { onEdit } = renderTable({ transactions: [tx] })
      fireEvent.click(screen.getByRole('button', { name: /edit/i }))
      expect(onEdit).toHaveBeenCalledWith(tx)
    })

    it('calls onApprove with the transaction when Approve is clicked', () => {
      const tx = makeTx({ id: 7, status: 'pending' })
      const { onApprove } = renderTable({ transactions: [tx] })
      fireEvent.click(screen.getByRole('button', { name: /^approve$/i }))
      expect(onApprove).toHaveBeenCalledWith(tx)
    })

    it('calls onDelete with the transaction when Delete is clicked', () => {
      const tx = makeTx({ id: 7 })
      const { onDelete } = renderTable({ transactions: [tx] })
      fireEvent.click(screen.getByRole('button', { name: /delete/i }))
      expect(onDelete).toHaveBeenCalledWith(tx)
    })
  })

  describe('sort indicator + onSortChange', () => {
    it('renders an active down arrow on the currently-sorted column', () => {
      renderTable({ sort: 'date', direction: 'desc' })

      const dateHeader = screen.getByText(/^date/i).closest('th')!
      const indicator = dateHeader.querySelector('.sort-indicator')
      expect(indicator?.classList.contains('active')).toBe(true)
      expect(indicator?.textContent).toBe('↓')
    })

    it('renders an inactive ↕ on non-sorted columns', () => {
      renderTable({ sort: 'date', direction: 'desc' })

      const amountHeader = screen.getByText(/^amount/i).closest('th')!
      const indicator = amountHeader.querySelector('.sort-indicator')
      expect(indicator?.classList.contains('active')).toBe(false)
      expect(indicator?.textContent).toBe('↕')
    })

    it('calls onSortChange with the clicked field', () => {
      const { onSortChange } = renderTable({ sort: 'id', direction: 'desc' })

      fireEvent.click(screen.getByText(/^date/i).closest('th')!)
      expect(onSortChange).toHaveBeenCalledWith('date')

      fireEvent.click(screen.getByText(/^amount/i).closest('th')!)
      expect(onSortChange).toHaveBeenCalledWith('amount')
    })
  })
})
