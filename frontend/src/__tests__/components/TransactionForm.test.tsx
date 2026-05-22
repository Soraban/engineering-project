import { render, screen, fireEvent, waitFor, act } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { describe, it, expect, vi, beforeEach } from 'vitest'

const { mockCreate, mockUpdate } = vi.hoisted(() => ({
  mockCreate: vi.fn(),
  mockUpdate: vi.fn(),
}))

vi.mock('../../api/client', () => ({
  createTransaction: mockCreate,
  updateTransaction: mockUpdate,
  deleteTransaction: vi.fn(),
  bulkAction: vi.fn(),
}))

import TransactionForm from '../../components/TransactionForm'
import type { Transaction } from '../../types'

function renderForm(props: { transaction?: Transaction | null; onClose?: () => void } = {}) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  return render(
    <QueryClientProvider client={client}>
      <TransactionForm transaction={props.transaction ?? null} onClose={props.onClose ?? vi.fn()} />
    </QueryClientProvider>
  )
}

const existingTx: Transaction = {
  id: 42,
  date: '2024-06-15',
  description: 'Amazon',
  description_normalized: 'amazon',
  amount: '49.99',
  category: 'Shopping',
  status: 'reviewed',
  source: 'manual',
  anomaly_flags: [],
  metadata: {},
  created_at: '2024-06-15T00:00:00Z',
  updated_at: '2024-06-15T00:00:00Z',
}

describe('TransactionForm', () => {
  beforeEach(() => {
    mockCreate.mockReset().mockResolvedValue(undefined)
    mockUpdate.mockReset().mockResolvedValue(undefined)
  })

  describe('create mode (no transaction prop)', () => {
    it('renders the Create button label', () => {
      renderForm()
      expect(screen.getByRole('button', { name: /create transaction/i })).toBeInTheDocument()
    })

    it('does NOT render the status dropdown (only edit mode shows it)', () => {
      renderForm()
      expect(screen.queryByLabelText(/^status$/i)).not.toBeInTheDocument()
    })

    it('calls createTransaction with parsed amount and nullable category on submit', async () => {
      renderForm()

      fireEvent.change(screen.getByLabelText(/date/i), { target: { value: '2024-07-01' } })
      fireEvent.change(screen.getByLabelText(/description/i), { target: { value: 'Spotify' } })
      fireEvent.change(screen.getByLabelText(/amount/i), { target: { value: '11.99' } })

      fireEvent.click(screen.getByRole('button', { name: /create transaction/i }))

      await waitFor(() => {
        expect(mockCreate).toHaveBeenCalledWith({
          date: '2024-07-01',
          description: 'Spotify',
          amount: 11.99,
          category: null,
        })
      })
    })
  })

  describe('edit mode (transaction prop provided)', () => {
    it('pre-populates every field from the transaction', () => {
      renderForm({ transaction: existingTx })

      expect((screen.getByLabelText(/date/i) as HTMLInputElement).value).toBe('2024-06-15')
      expect((screen.getByLabelText(/description/i) as HTMLInputElement).value).toBe('Amazon')
      expect((screen.getByLabelText(/amount/i) as HTMLInputElement).value).toBe('49.99')
      expect((screen.getByLabelText(/category/i) as HTMLSelectElement).value).toBe('Shopping')
      expect((screen.getByLabelText(/^status$/i) as HTMLSelectElement).value).toBe('reviewed')
    })

    it('renders the Save Changes label (not Create)', () => {
      renderForm({ transaction: existingTx })
      expect(screen.getByRole('button', { name: /save changes/i })).toBeInTheDocument()
    })

    it('shows the status dropdown with all three options', () => {
      renderForm({ transaction: existingTx })

      const statusField = screen.getByLabelText(/^status$/i)
      expect(statusField).toBeInTheDocument()
      expect(statusField.querySelectorAll('option').length).toBe(3)
    })

    it('does NOT send status in the payload when it has not changed', async () => {
      renderForm({ transaction: existingTx })

      // change just the description
      fireEvent.change(screen.getByLabelText(/description/i), { target: { value: 'Amazon Prime' } })
      fireEvent.click(screen.getByRole('button', { name: /save changes/i }))

      await waitFor(() => {
        expect(mockUpdate).toHaveBeenCalledWith(
          42,
          expect.not.objectContaining({ status: expect.anything() })
        )
      })
    })

    it('DOES send status when it changed (undo accidental approval case)', async () => {
      renderForm({ transaction: existingTx })

      // user wants to undo the accidental approval
      fireEvent.change(screen.getByLabelText(/^status$/i), { target: { value: 'pending' } })
      fireEvent.click(screen.getByRole('button', { name: /save changes/i }))

      await waitFor(() => {
        expect(mockUpdate).toHaveBeenCalledWith(
          42,
          expect.objectContaining({ status: 'pending' })
        )
      })
    })
  })

  describe('validation', () => {
    it('does not submit when required fields are missing', async () => {
      renderForm()

      // amount is required; we won't fill it.
      // Wrap the click in act() because react-hook-form's handleSubmit
      // triggers async validation that updates internal state — without
      // the wrap, React logs a "not wrapped in act" warning.
      fireEvent.change(screen.getByLabelText(/date/i), { target: { value: '2024-07-01' } })
      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /create transaction/i }))
      })

      expect(mockCreate).not.toHaveBeenCalled()
    })
  })
})
