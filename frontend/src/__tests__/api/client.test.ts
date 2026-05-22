import { describe, it, expect, vi, beforeEach } from 'vitest'

const { mockGet, mockPost, mockPut, mockPatch, mockDelete } = vi.hoisted(() => ({
  mockGet: vi.fn(),
  mockPost: vi.fn(),
  mockPut: vi.fn(),
  mockPatch: vi.fn(),
  mockDelete: vi.fn(),
}))

vi.mock('axios', () => ({
  default: {
    create: () => ({
      get: mockGet,
      post: mockPost,
      put: mockPut,
      patch: mockPatch,
      delete: mockDelete,
      interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
    }),
  },
}))

import * as api from '../../api/client'

describe('api/client', () => {
  beforeEach(() => {
    mockGet.mockReset()
    mockPost.mockReset()
    mockPut.mockReset()
    mockPatch.mockReset()
    mockDelete.mockReset()
  })

  describe('createTransaction', () => {
    it('POSTs to /transactions wrapping the body in { transaction: ... }', async () => {
      mockPost.mockResolvedValueOnce({ data: { id: 1 } })

      await api.createTransaction({ date: '2024-01-01', amount: 49.99, description: 'Test' })

      expect(mockPost).toHaveBeenCalledWith('/transactions', {
        transaction: { date: '2024-01-01', amount: 49.99, description: 'Test' },
      })
    })

    it('returns the response data', async () => {
      mockPost.mockResolvedValueOnce({ data: { id: 42, amount: '49.99' } })

      const result = await api.createTransaction({ amount: 49.99 })

      expect(result).toEqual({ id: 42, amount: '49.99' })
    })
  })

  describe('updateTransaction', () => {
    it('PATCHes to /transactions/:id with body wrapped in { transaction: ... }', async () => {
      mockPatch.mockResolvedValueOnce({ data: { id: 42 } })

      await api.updateTransaction(42, { category: 'Travel', approve: true })

      expect(mockPatch).toHaveBeenCalledWith('/transactions/42', {
        transaction: { category: 'Travel', approve: true },
      })
    })
  })

  describe('deleteTransaction', () => {
    it('DELETEs /transactions/:id', async () => {
      mockDelete.mockResolvedValueOnce({})

      await api.deleteTransaction(99)

      expect(mockDelete).toHaveBeenCalledWith('/transactions/99')
    })
  })

  describe('bulkAction', () => {
    it('PUTs to /transactions/bulk with snake_case action_type', async () => {
      mockPut.mockResolvedValueOnce({ data: { updated_count: 3 } })

      await api.bulkAction([1, 2, 3], 'set_category', 'Travel')

      expect(mockPut).toHaveBeenCalledWith('/transactions/bulk', {
        ids: [1, 2, 3],
        action_type: 'set_category',
        value: 'Travel',
      })
    })

    it('returns the response payload (e.g., { updated_count })', async () => {
      mockPut.mockResolvedValueOnce({ data: { updated_count: 5 } })

      const result = await api.bulkAction([1, 2], 'approve')

      expect(result).toEqual({ updated_count: 5 })
    })
  })

  describe('countTransactions', () => {
    it('GETs /transactions/count and unwraps the count number', async () => {
      mockGet.mockResolvedValueOnce({ data: { count: 2450 } })

      const result = await api.countTransactions({ status: 'flagged' })

      expect(mockGet).toHaveBeenCalledWith('/transactions/count', { params: { status: 'flagged' } })
      expect(result).toBe(2450)
    })

    it('passes empty params object when no filters are provided', async () => {
      mockGet.mockResolvedValueOnce({ data: { count: 0 } })

      await api.countTransactions()

      expect(mockGet).toHaveBeenCalledWith('/transactions/count', { params: {} })
    })
  })

  describe('fetchTransactions', () => {
    it('GETs /transactions with the filter params', async () => {
      mockGet.mockResolvedValueOnce({ data: { transactions: [] } })

      await api.fetchTransactions({ status: 'pending', sort: 'date', direction: 'asc', page: 2 })

      expect(mockGet).toHaveBeenCalledWith('/transactions', {
        params: { status: 'pending', sort: 'date', direction: 'asc', page: 2 },
      })
    })
  })

  describe('fetchDashboard', () => {
    it('GETs /dashboard with the filter param when provided', async () => {
      mockGet.mockResolvedValueOnce({ data: {} })

      await api.fetchDashboard({ filter: 'high', page: 1 })

      expect(mockGet).toHaveBeenCalledWith('/dashboard', { params: { filter: 'high', page: 1 } })
    })

    it('GETs /dashboard with no params when called with empty object', async () => {
      mockGet.mockResolvedValueOnce({ data: {} })

      await api.fetchDashboard()

      expect(mockGet).toHaveBeenCalledWith('/dashboard', { params: {} })
    })
  })
})
