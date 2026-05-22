import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { describe, it, expect, vi } from 'vitest'
import BulkActionBar from '../../components/BulkActionBar'

vi.mock('../../hooks/useTransactions', () => ({
  useBulkAction: () => ({
    mutate: vi.fn((_, opts) => opts?.onSuccess?.()),
  }),
}))

function renderWithProviders(ui: React.ReactElement) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(<QueryClientProvider client={client}>{ui}</QueryClientProvider>)
}

describe('BulkActionBar', () => {
  it('is hidden when no rows are selected', () => {
    const { container } = renderWithProviders(<BulkActionBar selectedIds={[]} onApply={vi.fn()} />)
    expect(container.querySelector('.bulk-bar')).toHaveClass('hidden')
  })

  it('shows count when rows are selected', () => {
    renderWithProviders(<BulkActionBar selectedIds={[1, 2, 3]} onApply={vi.fn()} />)
    expect(screen.getByText(/3 selected/i)).toBeInTheDocument()
  })

  it('shows visible bar when rows are selected', () => {
    const { container } = renderWithProviders(<BulkActionBar selectedIds={[1, 2]} onApply={vi.fn()} />)
    expect(container.querySelector('.bulk-bar')).not.toHaveClass('hidden')
  })
})
