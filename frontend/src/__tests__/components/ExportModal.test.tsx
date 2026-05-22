import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'

const { mockCount, mockExport } = vi.hoisted(() => ({
  mockCount: vi.fn(),
  mockExport: vi.fn(),
}))

vi.mock('../../api/client', () => ({
  countTransactions: mockCount,
  exportTransactions: mockExport,
}))

import ExportModal from '../../components/ExportModal'

describe('ExportModal', () => {
  beforeEach(() => {
    mockCount.mockReset()
    mockExport.mockReset()
    mockCount.mockResolvedValue(42)
    mockExport.mockResolvedValue(undefined)
  })

  // The modal fires a `countTransactions` call in a useEffect on mount.
  // Even tests that don't care about the count have to await it, otherwise
  // its setState fires after the test ends and React logs an act() warning.
  it('renders date range, status, and category fields', async () => {
    render(<ExportModal onClose={vi.fn()} />)

    expect(screen.getByText(/from date/i)).toBeInTheDocument()
    expect(screen.getByText(/to date/i)).toBeInTheDocument()
    expect(screen.getByText(/^status$/i)).toBeInTheDocument()
    expect(screen.getByText(/^category$/i)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /download csv/i })).toBeInTheDocument()

    await waitFor(() => expect(mockCount).toHaveBeenCalled())
  })

  it('pre-populates fields from initialFilters', async () => {
    render(
      <ExportModal
        initialFilters={{ date_from: '2024-01-01', date_to: '2024-12-31', status: 'flagged', category: 'Travel' }}
        onClose={vi.fn()}
      />
    )

    expect((screen.getByLabelText(/from date/i) as HTMLInputElement).value).toBe('2024-01-01')
    expect((screen.getByLabelText(/to date/i) as HTMLInputElement).value).toBe('2024-12-31')
    expect((screen.getByLabelText(/^status$/i) as HTMLSelectElement).value).toBe('flagged')
    expect((screen.getByLabelText(/^category$/i) as HTMLSelectElement).value).toBe('Travel')

    await waitFor(() => expect(mockCount).toHaveBeenCalled())
  })

  it('fetches and displays the matching count', async () => {
    mockCount.mockResolvedValue(2450)

    render(<ExportModal onClose={vi.fn()} />)

    await waitFor(() => {
      expect(screen.getByText(/2,450/)).toBeInTheDocument()
    })
    expect(mockCount).toHaveBeenCalled()
  })

  it('re-fetches the count when a filter changes', async () => {
    render(<ExportModal onClose={vi.fn()} />)

    await waitFor(() => expect(mockCount).toHaveBeenCalledTimes(1))

    fireEvent.change(screen.getByLabelText(/^status$/i), { target: { value: 'flagged' } })

    await waitFor(() => expect(mockCount).toHaveBeenCalledTimes(2))
    expect(mockCount).toHaveBeenLastCalledWith(expect.objectContaining({ status: 'flagged' }))
  })

  it('calls exportTransactions with the current filters on download', async () => {
    const onClose = vi.fn()
    render(<ExportModal onClose={onClose} />)

    fireEvent.change(screen.getByLabelText(/from date/i), { target: { value: '2024-01-01' } })
    fireEvent.change(screen.getByLabelText(/^category$/i), { target: { value: 'Travel' } })

    fireEvent.click(screen.getByRole('button', { name: /download csv/i }))

    await waitFor(() => {
      expect(mockExport).toHaveBeenCalledWith(
        expect.objectContaining({ date_from: '2024-01-01', category: 'Travel' })
      )
    })
    await waitFor(() => expect(onClose).toHaveBeenCalled())
  })

  it('disables the download button when the count is 0', async () => {
    mockCount.mockResolvedValue(0)

    render(<ExportModal onClose={vi.fn()} />)

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /download csv/i })).toBeDisabled()
    })
  })

  it('closes when Cancel is clicked', async () => {
    const onClose = vi.fn()
    render(<ExportModal onClose={onClose} />)

    fireEvent.click(screen.getByRole('button', { name: /cancel/i }))

    expect(onClose).toHaveBeenCalled()

    await waitFor(() => expect(mockCount).toHaveBeenCalled())
  })
})
