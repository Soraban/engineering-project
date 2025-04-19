"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ArrowDown, ArrowUp, DollarSign, AlertCircle } from "lucide-react";
import { useUser } from "@clerk/nextjs";
import { api } from "~/trpc/react";
import { redirect } from "next/navigation";
import { formatCurrency } from "~/lib/utils";

export default function DashboardPage() {
  const { user } = useUser();
  const { data: transactions, isLoading: isLoadingTransactions } = api.transaction.getAll.useQuery(
    { userId: user?.id ?? "" },
    { enabled: !!user }
  );
  const { data: reviewTransactions, isLoading: isLoadingReviews } = api.transaction.getNeedingReview.useQuery(
    { userId: user?.id ?? "" },
    { enabled: !!user }
  );

  if (!user) {
    redirect("/sign-in");
  }

  if (isLoadingTransactions || isLoadingReviews) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="text-center text-muted-foreground">
          Loading dashboard...
        </div>
      </div>
    );
  }

  // Calculate analytics
  const totalIncome = transactions?.reduce((sum, t) => {
    const amount = parseFloat(t.amount);
    return amount > 0 ? sum + amount : sum;
  }, 0) ?? 0;

  const totalExpenses = transactions?.reduce((sum, t) => {
    const amount = parseFloat(t.amount);
    return amount < 0 ? sum + Math.abs(amount) : sum;
  }, 0) ?? 0;

  const netBalance = totalIncome - totalExpenses;
  const itemsToReview = reviewTransactions?.length ?? 0;

  // Get recent transactions
  const recentTransactions = transactions?.slice(0, 5) ?? [];

  // Calculate category totals
  const categoryTotals = transactions?.reduce((acc, t) => {
    if (t.categories && t.categories.length > 0) {
      t.categories.forEach(category => {
        const categoryName = category.name;
        const amount = parseFloat(t.amount);
        // For expenses, only count negative amounts
        if (amount < 0) {
          acc[categoryName] = (acc[categoryName] ?? 0) + Math.abs(amount);
        }
      });
    }
    return acc;
  }, {} as Record<string, number>) ?? {};

  // Convert to array and sort by amount
  const categoryOverview = Object.entries(categoryTotals)
    .map(([name, amount]) => ({ name, amount }))
    .sort((a, b) => b.amount - a.amount)
    .slice(0, 5);

  // Calculate total expenses for percentage (only from categories)
  const totalExpensesForPercentage = Object.values(categoryTotals).reduce((sum, amount) => sum + amount, 0) || 1; // Prevent division by zero

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">Dashboard</h1>

      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4 mb-8">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Income</CardTitle>
            <ArrowUp className="h-4 w-4 text-green-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{formatCurrency(totalIncome)}</div>
            <p className="text-xs text-muted-foreground">
              {transactions?.length ?? 0} transactions
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Expenses</CardTitle>
            <ArrowDown className="h-4 w-4 text-red-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{formatCurrency(totalExpenses)}</div>
            <p className="text-xs text-muted-foreground">
              {transactions?.length ?? 0} transactions
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Net Balance</CardTitle>
            <DollarSign className="h-4 w-4 text-blue-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{formatCurrency(netBalance)}</div>
            <p className="text-xs text-muted-foreground">
              {netBalance >= 0 ? "Positive" : "Negative"} balance
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Items to Review</CardTitle>
            <AlertCircle className="h-4 w-4 text-yellow-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{itemsToReview}</div>
            <p className="text-xs text-muted-foreground">
              {itemsToReview === 0 ? "All clear!" : "Needs attention"}
            </p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Recent Transactions</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {recentTransactions.map((transaction) => (
                <div key={transaction.id} className="flex items-center justify-between">
                  <div>
                    <p className="font-medium">{transaction.description ?? "No Description"}</p>
                    <p className="text-sm text-muted-foreground">
                      {new Date(transaction.date).toLocaleDateString()}
                    </p>
                  </div>
                  <p className={parseFloat(transaction.amount) >= 0 ? "text-green-500" : "text-red-500"}>
                    {formatCurrency(parseFloat(transaction.amount))}
                  </p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Most Used Categories</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {(() => {
                // Count transactions per category
                const categoryCount: Record<string, { count: number; name: string }> = {};
                
                transactions?.forEach(transaction => {
                  transaction.categories?.forEach(category => {
                    const categoryEntry = categoryCount[category.id];
                    if (!categoryEntry) {
                      categoryCount[category.id] = { count: 0, name: category.name };
                    }
                    categoryCount[category.id]!.count++;
                  });
                });

                // Convert to array and sort by count
                return Object.entries(categoryCount)
                  .map(([id, { count, name }]) => ({ id, name, count }))
                  .sort((a, b) => b.count - a.count)
                  .slice(0, 5)
                  .map(category => (
                    <div key={category.id} className="flex items-center justify-between">
                      <div>
                        <p className="font-medium">{category.name}</p>
                        <p className="text-sm text-muted-foreground">
                          {category.count} transaction{category.count !== 1 ? 's' : ''}
                        </p>
                      </div>
                      <p className="text-muted-foreground">
                        {Math.round((category.count / (transactions?.length ?? 1)) * 100)}%
                      </p>
                    </div>
                  ));
              })()}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
} 