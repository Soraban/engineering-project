"use client";

import { useUser } from "@clerk/nextjs";
import { api } from "~/trpc/react";
import { redirect } from "next/navigation";
import { TransactionForm } from "~/app/_components/TransactionForm";

interface ReviewPageClientProps {
  transactionId: string;
}

export function ReviewPageClient({ transactionId }: ReviewPageClientProps) {
  const { user } = useUser();
  const { data: transaction, isLoading } = api.transaction.getById.useQuery(
    { 
      userId: user?.id ?? "", 
      transactionId 
    },
    { 
      enabled: !!user,
      retry: false
    }
  );

  if (!user?.id) {
    redirect("/sign-in");
  }

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="text-center text-muted-foreground">
          Loading transaction...
        </div>
      </div>
    );
  }

  if (!transaction) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="text-center text-destructive">
          Transaction not found.
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-2xl font-bold mb-6">Review Transaction</h1>
        <TransactionForm 
          userId={user.id}
          initialData={{
            id: transaction.id,
            amount: transaction.amount,
            description: transaction.description ?? undefined,
            date: transaction.date.toISOString(),
            categoryIds: transaction.categories.map(c => c.id)
          }}
        />
      </div>
    </div>
  );
} 