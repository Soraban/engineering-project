import { useForm } from '@mantine/form';
import { TextInput, NumberInput, Button, Stack, Group } from '@mantine/core';
import { useMutation, useQueryClient } from 'react-query';
import { api } from '../services/api';
import { CreateTransactionData } from '../types/transaction';

export function CreateTransaction() {
  const queryClient = useQueryClient();
  const form = useForm<CreateTransactionData>({
    initialValues: {
      date: new Date().toISOString().split('T')[0],
      description: '',
      amount: 0,
      category: undefined,
      flagged: false,
    },
  });

  const createMutation = useMutation(
    (data: CreateTransactionData) => api.transactions.create(data),
    {
      onSuccess: () => {
        queryClient.invalidateQueries('transactions');
        form.reset();
      },
    }
  );

  return (
    <form onSubmit={form.onSubmit((values) => createMutation.mutate(values))}>
      <Stack>
        <TextInput
          label="Date"
          type="date"
          {...form.getInputProps('date')}
        />
        <TextInput
          label="Description"
          {...form.getInputProps('description')}
        />
        <NumberInput
          label="Amount"
          decimalScale={2}
          fixedDecimalScale
          step={0.01}
          {...form.getInputProps('amount')}
        />
        <Group justify="flex-end">
          <Button type="submit" loading={createMutation.isLoading}>
            Create Transaction
          </Button>
        </Group>
      </Stack>
    </form>
  );
} 