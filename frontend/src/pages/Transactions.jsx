import { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { transactionAPI, categoryAPI } from '../services/api';
import CSVImport from '../components/CSVImport';
import BulkCategorize from '../components/BulkCategorize';

const Transactions = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [transactions, setTransactions] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedTransactions, setSelectedTransactions] = useState([]);
  const [showImport, setShowImport] = useState(false);
  const [showBulkCategorize, setShowBulkCategorize] = useState(false);
  const [showTransactionForm, setShowTransactionForm] = useState(false);
  const [editingTransaction, setEditingTransaction] = useState(null);
  const [activeImports, setActiveImports] = useState([]);
  const [pagination, setPagination] = useState({
    currentPage: parseInt(searchParams.get('page')) || 1,
    totalPages: 1,
    totalCount: 0,
  });
  const [filters, setFilters] = useState({
    uncategorized: searchParams.get('uncategorized') === 'true',
    flagged: searchParams.get('flagged') === 'true',
    category_id: searchParams.get('category_id') || '',
  });

  useEffect(() => {
    fetchTransactions();
    fetchCategories();
  }, [filters, pagination.currentPage]);

  // Poll for active imports
  useEffect(() => {
    const fetchActiveImports = async () => {
      try {
        const response = await transactionAPI.getActiveImports();
        setActiveImports(response.data || []);

        // If there are no more active imports, refresh transactions
        if (activeImports.length > 0 && response.data.length === 0) {
          fetchTransactions();
        }
      } catch (err) {
        console.error('Error fetching active imports:', err);
      }
    };

    // Initial fetch
    fetchActiveImports();

    // Poll every 2 seconds
    const pollInterval = setInterval(fetchActiveImports, 2000);

    return () => clearInterval(pollInterval);
  }, []);

  const fetchTransactions = async () => {
    try {
      setLoading(true);
      const params = { page: pagination.currentPage };
      if (filters.uncategorized) params.uncategorized = 'true';
      if (filters.flagged) params.flagged = 'true';
      if (filters.category_id) params.category_id = filters.category_id;

      const response = await transactionAPI.getAll(params);
      setTransactions(response.data.transactions || []);
      if (response.data.meta) {
        setPagination({
          currentPage: response.data.meta.current_page,
          totalPages: response.data.meta.total_pages,
          totalCount: response.data.meta.total_count,
        });
      }
      setError(null);
    } catch (err) {
      setError('Failed to load transactions');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchCategories = async () => {
    try {
      const response = await categoryAPI.getAll();
      setCategories(response.data || []);
    } catch (err) {
      console.error('Failed to load categories', err);
    }
  };

  const handleFilterChange = (key, value) => {
    const newFilters = { ...filters, [key]: value };
    setFilters(newFilters);
    setPagination({ ...pagination, currentPage: 1 }); // Reset to page 1 when filtering

    // Update URL params
    const params = new URLSearchParams();
    params.set('page', '1');
    if (newFilters.uncategorized) params.set('uncategorized', 'true');
    if (newFilters.flagged) params.set('flagged', 'true');
    if (newFilters.category_id) params.set('category_id', newFilters.category_id);
    setSearchParams(params);
  };

  const handlePageChange = (newPage) => {
    setPagination({ ...pagination, currentPage: newPage });
    const params = new URLSearchParams(searchParams);
    params.set('page', newPage.toString());
    setSearchParams(params);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleSelectTransaction = (id) => {
    setSelectedTransactions((prev) =>
      prev.includes(id) ? prev.filter((t) => t !== id) : [...prev, id]
    );
  };

  const handleSelectAll = () => {
    if (selectedTransactions.length === transactions.length) {
      setSelectedTransactions([]);
    } else {
      setSelectedTransactions(transactions.map((t) => t.id));
    }
  };

  const handleDelete = async (id) => {
    if (!confirm('Are you sure you want to delete this transaction?')) return;

    try {
      await transactionAPI.delete(id);
      fetchTransactions();
    } catch (err) {
      alert('Failed to delete transaction');
      console.error(err);
    }
  };

  const handleEdit = (transaction) => {
    setEditingTransaction(transaction);
    setShowTransactionForm(true);
  };

  const handleApprove = async (transaction) => {
    try {
      await transactionAPI.update(transaction.id, { reviewed: true });
      fetchTransactions();
    } catch (err) {
      alert('Failed to approve transaction');
      console.error(err);
    }
  };

  const handleTransactionFormClose = () => {
    setShowTransactionForm(false);
    setEditingTransaction(null);
  };

  const handleTransactionFormSuccess = () => {
    handleTransactionFormClose();
    fetchTransactions();
  };

  const handleImportSuccess = (jobId) => {
    setShowImport(false);
  };

  const handleBulkCategorizeSuccess = () => {
    setShowBulkCategorize(false);
    setSelectedTransactions([]);
    fetchTransactions();
  };

  if (loading && transactions.length === 0) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="text-gray-500">Loading transactions...</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Active Imports */}
      {activeImports.length > 0 && (
        <div className="space-y-3">
          <h3 className="text-lg font-semibold text-gray-900">Active Imports ({activeImports.length})</h3>
          {activeImports.map((importJob) => (
            <div key={importJob.id} className="bg-white rounded-lg shadow p-4">
              <div className="flex justify-between items-center mb-2">
                <div>
                  <h4 className="font-medium text-gray-900">{importJob.filename}</h4>
                  <p className="text-xs text-gray-500">
                    {importJob.status === 'processing' ? 'Importing...' :
                     importJob.status === 'pending' ? 'Queued' :
                     importJob.status}
                  </p>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-sm text-gray-700 font-medium">
                    {importJob.progress_percentage}%
                  </span>
                  {(importJob.status === 'processing' || importJob.status === 'pending') && (
                    <button
                      onClick={async () => {
                        const action = importJob.status === 'pending' ? 'delete' : 'cancel';
                        if (confirm(`Are you sure you want to ${action} this import?`)) {
                          try {
                            await transactionAPI.cancelImport(importJob.id);
                          } catch (err) {
                            console.error(`Failed to ${action} import:`, err);
                          }
                        }
                      }}
                      className="px-3 py-1 text-sm bg-red-600 text-white rounded hover:bg-red-700"
                    >
                      {importJob.status === 'pending' ? 'Delete' : 'Cancel'}
                    </button>
                  )}
                </div>
              </div>

              {/* Progress Bar */}
              <div className="w-full bg-gray-200 rounded-full h-2 mb-2">
                <div
                  className="h-2 rounded-full transition-all duration-300 bg-blue-600"
                  style={{ width: `${importJob.progress_percentage}%` }}
                ></div>
              </div>

              {/* Stats */}
              <div className="text-xs text-gray-600 flex gap-4">
                <span>Processed: {importJob.processed_rows} / {importJob.total_rows}</span>
                <span className="text-green-700">✅ {importJob.successful_rows}</span>
                {importJob.failed_rows > 0 && (
                  <span className="text-red-700">❌ {importJob.failed_rows}</span>
                )}
              </div>

              {/* Errors */}
              {importJob.errors && importJob.errors.length > 0 && (
                <div className="mt-2 bg-red-50 border border-red-200 rounded p-2">
                  <p className="text-xs font-medium text-red-900 mb-1">Recent Errors:</p>
                  <div className="max-h-20 overflow-y-auto text-xs text-red-800">
                    {importJob.errors.slice(0, 3).map((error, index) => (
                      <div key={index} className="mb-1">
                        {error.message || error.errors?.join(', ')}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-3xl font-bold text-gray-900">Transactions</h2>
          <p className="mt-2 text-gray-600">
            Manage and categorize your transactions
          </p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={async () => {
              if (confirm('Are you sure you want to delete ALL transactions? This cannot be undone.')) {
                try {
                  await transactionAPI.deleteAll();
                  fetchTransactions();
                } catch (err) {
                  alert('Failed to delete transactions');
                  console.error(err);
                }
              }
            }}
            className="bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 font-medium"
          >
            Delete All
          </button>
          <button
            onClick={() => setShowTransactionForm(true)}
            className="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 font-medium"
          >
            Add Transaction
          </button>
          <button
            onClick={() => setShowImport(true)}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 font-medium"
          >
            Import CSV
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white p-4 rounded-lg shadow space-y-4">
        <div className="flex flex-wrap gap-4">
          <label className="flex items-center space-x-2">
            <input
              type="checkbox"
              checked={filters.uncategorized}
              onChange={(e) => handleFilterChange('uncategorized', e.target.checked)}
              className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <span className="text-sm font-medium text-gray-700">
              Uncategorized only
            </span>
          </label>

          <label className="flex items-center space-x-2">
            <input
              type="checkbox"
              checked={filters.flagged}
              onChange={(e) => handleFilterChange('flagged', e.target.checked)}
              className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
            />
            <span className="text-sm font-medium text-gray-700">
              Flagged only
            </span>
          </label>

          <select
            value={filters.category_id}
            onChange={(e) => handleFilterChange('category_id', e.target.value)}
            className="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">All Categories</option>
            {categories.map((category) => (
              <option key={category.id} value={category.id}>
                {category.name}
              </option>
            ))}
          </select>

          {(filters.uncategorized || filters.flagged || filters.category_id) && (
            <button
              onClick={() => {
                setFilters({ uncategorized: false, flagged: false, category_id: '' });
                setSearchParams(new URLSearchParams());
              }}
              className="text-sm text-blue-600 hover:text-blue-800 font-medium"
            >
              Clear Filters
            </button>
          )}
        </div>
      </div>

      {/* Bulk Actions */}
      {selectedTransactions.length > 0 && (
        <div className="bg-blue-50 border border-blue-200 p-4 rounded-lg flex justify-between items-center">
          <span className="text-blue-900 font-medium">
            {selectedTransactions.length} transaction(s) selected
          </span>
          <button
            onClick={() => setShowBulkCategorize(true)}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 font-medium"
          >
            Categorize Selected
          </button>
        </div>
      )}

      {/* Pagination */}
      {transactions.length > 0 && pagination.totalPages > 1 && (
        <div className="flex items-center justify-between bg-white px-6 py-4 rounded-lg shadow">
          <div className="text-sm text-gray-700">
            Showing page <span className="font-medium">{pagination.currentPage}</span> of{' '}
            <span className="font-medium">{pagination.totalPages}</span> ({pagination.totalCount} total transactions)
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => handlePageChange(pagination.currentPage - 1)}
              disabled={pagination.currentPage === 1}
              className="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Previous
            </button>

            {/* Page Numbers */}
            <div className="flex gap-1">
              {[...Array(Math.min(5, pagination.totalPages))].map((_, i) => {
                let pageNum;
                if (pagination.totalPages <= 5) {
                  pageNum = i + 1;
                } else if (pagination.currentPage <= 3) {
                  pageNum = i + 1;
                } else if (pagination.currentPage >= pagination.totalPages - 2) {
                  pageNum = pagination.totalPages - 4 + i;
                } else {
                  pageNum = pagination.currentPage - 2 + i;
                }

                return (
                  <button
                    key={pageNum}
                    onClick={() => handlePageChange(pageNum)}
                    className={`px-4 py-2 border rounded-lg font-medium ${
                      pageNum === pagination.currentPage
                        ? 'bg-blue-600 text-white border-blue-600'
                        : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                    }`}
                  >
                    {pageNum}
                  </button>
                );
              })}
            </div>

            <button
              onClick={() => handlePageChange(pagination.currentPage + 1)}
              disabled={pagination.currentPage === pagination.totalPages}
              className="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next
            </button>
          </div>
        </div>
      )}

      {/* Transactions Table */}
      <div className="bg-white shadow rounded-lg overflow-hidden">
        {error && (
          <div className="bg-red-50 border-b border-red-200 p-4">
            <p className="text-red-800">{error}</p>
          </div>
        )}

        {transactions.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left">
                    <input
                      type="checkbox"
                      checked={
                        transactions.length > 0 &&
                        selectedTransactions.length === transactions.length
                      }
                      onChange={handleSelectAll}
                      className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                    />
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Date
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Description
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Amount
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Category
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {transactions.map((transaction) => (
                  <tr
                    key={transaction.id}
                    className={`hover:bg-gray-50 ${
                      transaction.flagged_as_anomaly ? 'bg-red-50' : ''
                    }`}
                  >
                    <td className="px-6 py-4">
                      <input
                        type="checkbox"
                        checked={selectedTransactions.includes(transaction.id)}
                        onChange={() => handleSelectTransaction(transaction.id)}
                        className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {new Date(transaction.transaction_date).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-900">
                      {transaction.description || (
                        <span className="text-gray-400 italic">No description</span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-right font-medium">
                      <span
                        className={
                          transaction.amount < 0 ? 'text-red-600' : 'text-green-600'
                        }
                      >
                        ${Math.abs(transaction.amount).toFixed(2)}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm">
                      {transaction.category ? (
                        <span
                          className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                          style={{
                            backgroundColor: transaction.category.color + '20',
                            color: transaction.category.color,
                          }}
                        >
                          {transaction.category.name}
                        </span>
                      ) : (
                        <span className="text-gray-400 italic">Uncategorized</span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm">
                      {transaction.flagged_as_anomaly && (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                          ⚠️ {transaction.anomaly_reason}
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-3">
                      {transaction.flagged_as_anomaly && !transaction.reviewed && (
                        <button
                          onClick={() => handleApprove(transaction)}
                          className="text-green-600 hover:text-green-900"
                        >
                          Approve
                        </button>
                      )}
                      <button
                        onClick={() => handleEdit(transaction)}
                        className="text-blue-600 hover:text-blue-900"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDelete(transaction.id)}
                        className="text-red-600 hover:text-red-900"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="px-6 py-12 text-center text-gray-500">
            <p className="text-lg">No transactions found</p>
            <p className="mt-2 text-sm">Import a CSV file to get started</p>
          </div>
        )}
      </div>

      {/* CSV Import Modal */}
      {showImport && (
        <CSVImport
          onClose={() => setShowImport(false)}
          onSuccess={handleImportSuccess}
        />
      )}

      {/* Bulk Categorize Modal */}
      {showBulkCategorize && (
        <BulkCategorize
          transactionIds={selectedTransactions}
          categories={categories}
          onClose={() => setShowBulkCategorize(false)}
          onSuccess={handleBulkCategorizeSuccess}
        />
      )}

      {/* Transaction Form Modal */}
      {showTransactionForm && (
        <TransactionForm
          transaction={editingTransaction}
          categories={categories}
          onClose={handleTransactionFormClose}
          onSuccess={handleTransactionFormSuccess}
        />
      )}
    </div>
  );
};

const TransactionForm = ({ transaction, categories, onClose, onSuccess }) => {
  const [formData, setFormData] = useState({
    transaction_date: transaction?.transaction_date || new Date().toISOString().split('T')[0],
    description: transaction?.description || '',
    amount: transaction?.amount || '',
    category_id: transaction?.category_id || '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  const handleChange = (field, value) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    try {
      setSaving(true);
      setError(null);

      if (transaction) {
        await transactionAPI.update(transaction.id, formData);
      } else {
        await transactionAPI.create(formData);
      }

      onSuccess();
    } catch (err) {
      setError(err.response?.data?.errors?.join(', ') || 'Failed to save transaction');
      console.error(err);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center z-50 overflow-y-auto pt-10">
      <div className="bg-white rounded-lg shadow-xl max-w-lg w-full mx-4 my-4">
        {/* Header */}
        <div className="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
          <h3 className="text-lg font-semibold text-gray-900">
            {transaction ? 'Edit Transaction' : 'New Transaction'}
          </h3>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
            disabled={saving}
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="px-6 py-4 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Date *
            </label>
            <input
              type="date"
              value={formData.transaction_date}
              onChange={(e) => handleChange('transaction_date', e.target.value)}
              required
              disabled={saving}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Description *
            </label>
            <input
              type="text"
              value={formData.description}
              onChange={(e) => handleChange('description', e.target.value)}
              required
              disabled={saving}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="e.g., Starbucks Coffee"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Amount *
            </label>
            <input
              type="number"
              step="0.01"
              value={formData.amount}
              onChange={(e) => handleChange('amount', e.target.value)}
              required
              disabled={saving}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="0.00"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Category
            </label>
            <select
              value={formData.category_id}
              onChange={(e) => handleChange('category_id', e.target.value)}
              disabled={saving}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">Uncategorized</option>
              {categories.map((category) => (
                <option key={category.id} value={category.id}>
                  {category.name}
                </option>
              ))}
            </select>
          </div>

          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-3">
              <p className="text-red-800 text-sm">{error}</p>
            </div>
          )}

          {/* Footer */}
          <div className="flex justify-end space-x-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              disabled={saving}
              className="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 font-medium"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={saving}
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {saving ? 'Saving...' : 'Save'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default Transactions;
