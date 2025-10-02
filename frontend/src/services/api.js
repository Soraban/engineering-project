import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/api/v1';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Transactions
export const transactionAPI = {
  getAll: (params = {}) => api.get('/transactions', { params }),
  getById: (id) => api.get(`/transactions/${id}`),
  create: (transaction) => api.post('/transactions', { transaction }),
  update: (id, transaction) => api.patch(`/transactions/${id}`, { transaction }),
  delete: (id) => api.delete(`/transactions/${id}`),
  import: (file) => {
    const formData = new FormData();
    formData.append('file', file);
    return api.post('/transactions/import', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
  getActiveImports: () => api.get('/transactions/active_imports'),
  getImportStatus: (importJobId) => api.get(`/transactions/import_status/${importJobId}`),
  cancelImport: (importJobId) => api.post(`/transactions/cancel_import/${importJobId}`),
  bulkCategorize: (transactionIds, categoryId) =>
    api.post('/transactions/bulk_categorize', {
      transaction_ids: transactionIds,
      category_id: categoryId,
    }),
  getReviewDashboard: () => api.get('/transactions/review_dashboard'),
  deleteAll: () => api.delete('/transactions/destroy_all'),
};

// Categories
export const categoryAPI = {
  getAll: () => api.get('/categories'),
  getById: (id) => api.get(`/categories/${id}`),
  create: (category) => api.post('/categories', { category }),
  update: (id, category) => api.patch(`/categories/${id}`, { category }),
  delete: (id) => api.delete(`/categories/${id}`),
};

// Rules
export const ruleAPI = {
  getAll: () => api.get('/rules'),
  getById: (id) => api.get(`/rules/${id}`),
  create: (rule) => api.post('/rules', { rule }),
  update: (id, rule) => api.patch(`/rules/${id}`, { rule }),
  delete: (id) => api.delete(`/rules/${id}`),
  apply: (id) => api.post(`/rules/${id}/apply`),
};

export default api;
