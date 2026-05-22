import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'

const { mockGet } = vi.hoisted(() => ({ mockGet: vi.fn() }))

vi.mock('axios', () => ({
  default: {
    create: () => ({
      get: mockGet,
      post: vi.fn(),
      put: vi.fn(),
      patch: vi.fn(),
      delete: vi.fn(),
      interceptors: {
        request: { use: vi.fn() },
        response: { use: vi.fn() },
      },
    }),
  },
}))

import { exportTransactions } from '../../api/client'

describe('exportTransactions', () => {
  let lastAnchor: HTMLAnchorElement | null

  beforeEach(() => {
    mockGet.mockReset()
    lastAnchor = null

    global.URL.createObjectURL = vi.fn(() => 'blob:mock-url')
    global.URL.revokeObjectURL = vi.fn()

    const originalCreateElement = document.createElement.bind(document)
    vi.spyOn(document, 'createElement').mockImplementation((tag: string) => {
      const el = originalCreateElement(tag) as HTMLElement
      if (tag === 'a') {
        lastAnchor = el as HTMLAnchorElement
        el.click = vi.fn()
      }
      return el
    })
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('calls the export endpoint with the provided filter params', async () => {
    mockGet.mockResolvedValueOnce({ data: 'id,date\n1,2024-01-01\n', headers: {} })

    await exportTransactions({ status: 'flagged', category: 'Travel' })

    expect(mockGet).toHaveBeenCalledWith(
      '/transactions/export',
      expect.objectContaining({
        params: { status: 'flagged', category: 'Travel' },
        responseType: 'blob',
      })
    )
  })

  it('triggers a browser download by clicking a generated anchor', async () => {
    mockGet.mockResolvedValueOnce({ data: 'csv', headers: {} })

    await exportTransactions({})

    expect(global.URL.createObjectURL).toHaveBeenCalled()
    expect(lastAnchor).not.toBeNull()
    expect(lastAnchor!.click).toHaveBeenCalled()
    expect(global.URL.revokeObjectURL).toHaveBeenCalledWith('blob:mock-url')
  })

  it('uses the filename from Content-Disposition when present', async () => {
    mockGet.mockResolvedValueOnce({
      data: 'csv',
      headers: { 'content-disposition': 'attachment; filename="transactions-2026-05-20.csv"' },
    })

    await exportTransactions({})

    expect(lastAnchor!.download).toBe('transactions-2026-05-20.csv')
  })

  it('falls back to a default filename when Content-Disposition is missing', async () => {
    mockGet.mockResolvedValueOnce({ data: 'csv', headers: {} })

    await exportTransactions({})

    expect(lastAnchor!.download).toMatch(/^transactions-\d{4}-\d{2}-\d{2}\.csv$/)
  })

  it('passes an empty params object when no filters are provided', async () => {
    mockGet.mockResolvedValueOnce({ data: 'csv', headers: {} })

    await exportTransactions()

    expect(mockGet).toHaveBeenCalledWith(
      '/transactions/export',
      expect.objectContaining({ params: {} })
    )
  })
})
