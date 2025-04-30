import { useState } from 'react';
import { useQuery } from 'react-query';
import { Table, Pagination, Text, Badge } from '@mantine/core';
import { api } from '../services/api';
import { Transaction } from '../types/transaction';

// This improved formatAmount function is bulletproof against type errors
const formatAmount = (amount: string | number | null | undefined): string => {
  // Handle null or undefined
  if (amount === null || amount === undefined) {
    return '$0.00';
  }
  
  // First convert to number safely, regardless of input type
  let numericAmount: number;
  
  try {
    // If it's already a number, this works fine
    // If it's a string, Number() will convert it
    numericAmount = Number(amount);
    
    // Check if we got a valid number
    if (isNaN(numericAmount) || !isFinite(numericAmount)) {
      return '$0.00';
    }
    
    // Format with 2 decimal places - ONLY call toFixed on a number
    return `$${numericAmount.toFixed(2)}`;
  } catch (error) {
    console.error('Error formatting amount:', error, amount);
    return '$0.00';
  }
};

export function TransactionsList() {
  const [page, setPage] = useState(1);
  const { data, isLoading, error } = useQuery(
    ['transactions', page],
    () => api.transactions.list(page),
    { 
      keepPreviousData: true,
      retry: 3,
      onError: (err) => {
        console.error('Error fetching transactions:', err);
      }
    }
  );

  if (isLoading) return <Text>Loading...</Text>;
  if (error) return <Text color="red">Error loading transactions: {(error as Error).message}</Text>;
  if (!data || !data.transactions) return <Text>No transactions found</Text>;

  const rows = data.transactions.map((transaction: Transaction) => (
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