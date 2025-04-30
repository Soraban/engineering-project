import { TransactionList } from '../components/TransactionList';
import { ImportTransactions } from '../components/ImportTransactions';

export function Transactions() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="space-y-8">
        <h1 className="text-3xl font-bold text-gray-900">Transactions</h1>
        <ImportTransactions />
        <TransactionList />
      </div>
    </div>
  );
} 