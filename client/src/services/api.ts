import axios from 'axios';
import { Transaction, TransactionResponse, CreateTransactionData } from '../types/transaction';

// Create axios instance with base configuration
const apiClient = axios.create({
  baseURL: 'http://localhost:3000/api/v1',
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 10000, // 10 seconds timeout
});

// Add response interceptor for better error handling
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    const errorMessage = error.response?.data?.message || error.message || 'Unknown error occurred';
    console.error('API Error:', errorMessage, error.config?.url);
    return Promise.reject(error);
  }
);

// Mock data for local development or when API is unavailable
const mockTransactionData: TransactionResponse = {
  transactions: [
    {
      id: 10809,
      date: "2025-02-14",
      description: "Airline Ticket",
      amount: "1227.45",
      category_id: null,
      flagged: false,
      metadata: {},
      created_at: "2025-04-29T08:51:57.181Z",
      updated_at: "2025-04-29T08:51:57.181Z",
      applied_rules: []
    },
    {
      id: 10806,
      date: "2024-11-30",
      description: "House Payment",
      amount: "2563.65",
      category_id: null,
      flagged: false,
      metadata: {},
      created_at: "2025-04-29T08:51:57.178Z",
      updated_at: "2025-04-29T08:51:57.178Z",
      applied_rules: []
    },
    // Add more mock transactions as needed
  ],
  pagination: {
    current_page: 1,
    next_page: null,
    prev_page: null,
    total_pages: 1,
    total_count: 9
  }
};

// API endpoints
export const api = {
  transactions: {
    list: async (page = 1, perPage = 10): Promise<TransactionResponse> => {
      try {
        const response = await apiClient.get(`/transactions?page=${page}&per_page=${perPage}`);
        return response.data;
      } catch (error) {
        console.warn('Failed to fetch transactions from API, using mock data', error);
        // Return mock data when API fails
        return mockTransactionData;
      }
    },
    
    create: async (data: CreateTransactionData): Promise<Transaction> => {
      const response = await apiClient.post('/transactions', data);
      return response.data;
    },
    
    update: async (id: number, data: Partial<CreateTransactionData>): Promise<Transaction> => {
      const response = await apiClient.put(`/transactions/${id}`, data);
      return response.data;
    },
    
    delete: async (id: number): Promise<void> => {
      await apiClient.delete(`/transactions/${id}`);
    },
    
    getById: async (id: number): Promise<Transaction> => {
      const response = await apiClient.get(`/transactions/${id}`);
      return response.data;
    }
  }
};