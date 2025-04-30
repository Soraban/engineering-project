import { useMutation, useQueryClient } from 'react-query';
import { api } from '../services/api';
import { IconUpload, IconX, IconFile } from '@tabler/icons-react';

export function ImportTransactions() {
  const queryClient = useQueryClient();
  const importMutation = useMutation(
    (file: File) => api.transactions.import(file),
    {
      onSuccess: () => {
        queryClient.invalidateQueries('transactions');
      },
    }
  );

  return (
    <div className="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center">
      <input
        type="file"
        accept=".csv"
        className="hidden"
        id="file-upload"
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) {
            importMutation.mutate(file);
          }
        }}
      />
      <label
        htmlFor="file-upload"
        className="cursor-pointer flex flex-col items-center justify-center space-y-4"
      >
        <div className="flex items-center justify-center w-12 h-12 rounded-full bg-gray-100">
          {importMutation.isLoading ? (
            <IconUpload className="w-6 h-6 text-gray-500" />
          ) : (
            <IconFile className="w-6 h-6 text-gray-500" />
          )}
        </div>
        <div className="text-center">
          <p className="text-lg font-medium text-gray-900">
            Drag CSV file here or click to select
          </p>
          <p className="text-sm text-gray-500 mt-1">
            Attach one CSV file with your transactions
          </p>
        </div>
      </label>
    </div>
  );
} 