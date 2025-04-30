import axios from 'axios';
import { CreateTransactionData, TransactionResponse } from '../types/transaction';

const API_BASE_URL = 'http://localhost:3000/api/v1';

export const api = {
  transactions: {
    list: async (page: number = 1, perPage: number = 100): Promise<TransactionResponse> => {
      const response = await axios.get(`${API_BASE_URL}/transactions`, {
        params: { page, per_page: perPage }
      });
      return response.data;
    },

    create: async (data: CreateTransactionData) => {
      const response = await axios.post(`${API_BASE_URL}/transactions`, {
        transaction: data
      });
      return response.data;
    },

    import: async (file: File) => {
      const formData = new FormData();
      formData.append('file', file);
      const response = await axios.post(`${API_BASE_URL}/transactions/import`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        }
      });
      return response.data;
    }
  }
}; 