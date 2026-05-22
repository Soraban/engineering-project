import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { fetchTransactions, updateTransaction, deleteTransaction, bulkAction, createTransaction } from '../api/client'
import type { Transaction } from '../types'

export interface TransactionsPage {
  transactions: Transaction[]
  page: number
  per_page: number
  total: number
  total_pages: number
}

export function useTransactions(filters: Record<string, string | number> = {}) {
  return useQuery<TransactionsPage>({
    queryKey: ['transactions', filters],
    queryFn: () => fetchTransactions(filters),
    placeholderData: (prev) => prev, // keeps old data visible while a new page loads
  })
}

export function useCreateTransaction() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (data: Record<string, unknown>) => createTransaction(data),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['transactions'] }),
  })
}

export function useUpdateTransaction() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, data }: { id: number; data: Record<string, unknown> }) =>
      updateTransaction(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactions'] })
      queryClient.invalidateQueries({ queryKey: ['dashboard'] })
    },
  })
}

export function useDeleteTransaction() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteTransaction(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactions'] })
      queryClient.invalidateQueries({ queryKey: ['dashboard'] })
    },
  })
}

export function useBulkAction() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ ids, actionType, value }: { ids: number[]; actionType: string; value?: string }) =>
      bulkAction(ids, actionType, value),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactions'] })
      queryClient.invalidateQueries({ queryKey: ['dashboard'] })
    },
  })
}
