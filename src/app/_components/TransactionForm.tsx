"use client";

import { api } from "~/trpc/react";
import { Button } from "~/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "~/components/ui/card";
import { Input } from "~/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";

const formSchema = z.object({
  description: z.string().min(1, "Description is required"),
  amount: z.string().min(1, "Amount is required").refine(
    (value) => !isNaN(parseFloat(value)) && parseFloat(value) !== 0,
    "Amount must be a valid non-zero number"
  ),
  date: z.string().min(1, "Date is required").refine(
    (value) => !isNaN(Date.parse(value)),
    "Please enter a valid date"
  ),
  categoryId: z.enum(["none"]).or(z.string().min(1)),
});

type FormValues = z.infer<typeof formSchema>;

interface TransactionFormProps {
  userId: string;
  initialData?: {
    id?: string;
    description?: string;
    amount: string;
    date?: string;
    categoryIds?: string[];
  };
}

export function TransactionForm({ userId, initialData }: TransactionFormProps) {
  const router = useRouter();
  const utils = api.useUtils();
  const applyRules = api.rule.applyRules.useMutation();

  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      description: initialData?.description ?? "",
      amount: initialData?.amount ?? "",
      date: initialData?.date ?? "",
      categoryId: initialData?.categoryIds?.[0] ?? "none",
    },
  });

  const { data: categories } = api.category.getAll.useQuery({ userId });
  
  const createTransaction = api.transaction.create.useMutation({
    onSuccess: async () => {
      try {
        await utils.transaction.getAll.invalidate({ userId });
        await applyRules.mutateAsync({ userId });
        toast.success("Transaction added successfully");
        router.push("/transactions");
      } catch (error) {
        console.error("Error in transaction creation:", error);
        toast.error("Failed to create transaction");
      }
    },
    onError: (error) => {
      toast.error(`Failed to create transaction: ${error.message}`);
    }
  });

  const updateTransaction = api.transaction.update.useMutation({
    onSuccess: async () => {
      try {
        await utils.transaction.getAll.invalidate({ userId });
        await applyRules.mutateAsync({ userId });
        toast.success("Transaction updated successfully");
        router.push("/transactions");
      } catch (error) {
        console.error("Error in transaction update:", error);
        toast.error("Failed to update transaction");
      }
    },
    onError: (error) => {
      toast.error(`Failed to update transaction: ${error.message}`);
    }
  });

  function onSubmit(values: FormValues) {
    if (initialData?.id) {
      // Update existing transaction
      updateTransaction.mutate({
        userId,
        transactionId: initialData.id,
        description: values.description,
        amount: values.amount,
        date: new Date(values.date),
        categoryIds: values.categoryId === "none" ? [] : [values.categoryId],
      });
    } else {
      // Create new transaction
      createTransaction.mutate({
        userId,
        description: values.description,
        amount: parseFloat(values.amount),
        date: new Date(values.date),
        categoryIds: values.categoryId === "none" ? undefined : [values.categoryId],
      });
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{initialData ? "Edit Transaction" : "Add New Transaction"}</CardTitle>
      </CardHeader>
      <CardContent>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Description</FormLabel>
                  <FormControl>
                    <Input placeholder="Enter transaction description" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="amount"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Amount</FormLabel>
                  <FormControl>
                    <Input
                      type="number"
                      step="0.01"
                      placeholder="Enter amount"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="date"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Date</FormLabel>
                  <FormControl>
                    <Input
                      type="date"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="categoryId"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Category</FormLabel>
                  <Select
                    onValueChange={field.onChange}
                    defaultValue={field.value}
                  >
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select a category" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value="none">None</SelectItem>
                      {categories?.map((category) => (
                        <SelectItem key={category.id} value={category.id}>
                          {category.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="flex justify-end space-x-4">
              <Button
                type="button"
                variant="outline"
                onClick={() => router.push("/transactions")}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={createTransaction.isPending || updateTransaction.isPending}
              >
                {createTransaction.isPending || updateTransaction.isPending 
                  ? "Saving..." 
                  : initialData 
                    ? "Save Changes" 
                    : "Add Transaction"}
              </Button>
            </div>

          </form>
        </Form>
      </CardContent>
    </Card>
  );
} 