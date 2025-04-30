import { useState } from 'react';
import { useQuery } from 'react-query';
import { Table, Pagination, Text, Badge } from '@mantine/core';
import { api } from '../services/api';
import { Transaction } from '../types/transaction';

const formatAmount = (amount: string | number | null | undefined): string => {
  // Handle null or undefined input
  if (amount === null || amount === undefined) {
    return '$0.00'; // Or return 'N/A' or '' based on preference
  }

  // Convert to number if it's a string
  const num = typeof amount === 'string' ? parseFloat(amount) : amount;

  // Check if the result is a valid, finite number
  if (isNaN(num) || !isFinite(num)) {
    return '$0.00'; // Or handle error appropriately
  }

  // Format with 2 decimal places
  return `$${num.toFixed(2)}`;
};

export function TransactionsList() {
  const [page, setPage] = useState(1);
  const { data, isLoading, error } = useQuery(
    ['transactions', page],
    () => api.transactions.list(page),
    { keepPreviousData: true }
  );

  if (isLoading) return <Text>Loading...</Text>;
  if (error) return <Text color="red">Error loading transactions</Text>;

  const rows = data?.transactions.map((transaction: Transaction) => (
    <Table.Tr key={transaction.id}>
      <Table.Td>{new Date(transaction.date).toLocaleDateString()}</Table.Td>
      <Table.Td>{transaction.description}</Table.Td>
      <Table.Td>{formatAmount(transaction.amount)}</Table.Td>
      <Table.Td>
        {transaction.category ? (
          <Badge color="blue">{transaction.category.name}</Badge>
        ) : (
          <Badge color="gray">Uncategorized</Badge>
        )}
      </Table.Td>
      <Table.Td>
        {transaction.flagged && <Badge color="red">Flagged</Badge>}
      </Table.Td>
    </Table.Tr>
  ));

  return (
    <div>
      <Table striped highlightOnHover>
        <Table.Thead>
          <Table.Tr>
            <Table.Th>Date</Table.Th>
            <Table.Th>Description</Table.Th>
            <Table.Th>Amount</Table.Th>
            <Table.Th>Category</Table.Th>
            <Table.Th>Status</Table.Th>
          </Table.Tr>
        </Table.Thead>
        <Table.Tbody>{rows}</Table.Tbody>
      </Table>

      {data?.pagination && (
        <Pagination
          total={data.pagination.total_pages}
          value={page}
          onChange={setPage}
          mt="sm"
        />
      )}
    </div>
  );
}