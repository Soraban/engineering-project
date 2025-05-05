'use client';

import TransactionsTable from '@/components/TransactionsTable';
import RulesManagement from '@/components/RulesComponent';

export default function TransactionsPage() {
  return (
    <div className="container mx-auto py-8">
      <h1 className="text-3xl font-bold mb-6">Transactions Dashboard</h1>
      <RulesManagement />
      <TransactionsTable />
    </div>
  );
}