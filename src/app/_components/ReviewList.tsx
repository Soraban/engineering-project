"use client";

import { api } from "~/trpc/react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { AlertCircle, Check, Trash2, Pencil } from "lucide-react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { useEffect } from "react";
import { ScrollArea } from "@/components/ui/scroll-area";
import { useRouter } from "next/navigation";

interface ReviewListProps {
  userId: string;
  maxHeight?: string;
}

export function ReviewList({ userId, maxHeight = "calc(100vh - 200px)" }: ReviewListProps) {
  const router = useRouter();
  const utils = api.useUtils();
  
  // Get flagged transactions
  const { data: transactions, isLoading, error } = api.transaction.getNeedingReview.useQuery(
    { userId },
    {
      enabled: !!userId,
      retry: false,
    }
  );

  // Show error toast if there's an error
  useEffect(() => {
    if (error) {
      toast.error(`Failed to fetch transactions: ${error.message}`);
    }
  }, [error]);

  // Mutations for approving and deleting transactions
  const approveMutation = api.transaction.approve.useMutation({
    onSuccess: async () => {
      await utils.transaction.getNeedingReview.invalidate({ userId });
      toast.success("Transaction approved successfully");
    },
    onError: (error) => {
      toast.error(`Failed to approve transaction: ${error.message}`);
    }
  });

  const deleteMutation = api.transaction.delete.useMutation({
    onSuccess: async () => {
      // Invalidate both queries to prevent flagging deleted transactions
      await Promise.all([
        utils.transaction.getNeedingReview.invalidate({ userId }),
        utils.transaction.getAll.invalidate({ userId })
      ]);
      toast.success("Transaction deleted successfully");
    },
    onError: (error) => {
      toast.error(`Failed to delete transaction: ${error.message}`);
    }
  });

  const handleApprove = async (e: React.MouseEvent, transactionId: string) => {
    e.stopPropagation();
    try {
      await approveMutation.mutateAsync({ userId, transactionId });
    } catch (error) {
      console.error("Error approving transaction:", error);
    }
  };

  const handleDelete = async (e: React.MouseEvent, transactionId: string) => {
    e.stopPropagation();
    try {
      await deleteMutation.mutateAsync({ userId, transactionId });
    } catch (error) {
      console.error("Error deleting transaction:", error);
    }
  };

  const handleTransactionClick = (transactionId: string) => {
    router.push(`/reviews/${transactionId}`);
  };

  if (isLoading) {
    return (
      <Card>
        <CardContent className="p-6">
          <p className="text-center text-muted-foreground">
            Loading transactions...
          </p>
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return (
      <Card>
        <CardContent className="p-6">
          <p className="text-center text-destructive">
            Error loading transactions. Please try again.
          </p>
        </CardContent>
      </Card>
    );
  }

  if (!transactions || transactions.length === 0) {
    return (
      <Card>
        <CardContent className="p-6">
          <p className="text-center text-muted-foreground">
            No transactions need review at this time.
          </p>
        </CardContent>
      </Card>
    );
  }

  const getFlagColor = (flag: string) => {
    switch (flag) {
      case "incomplete":
        return "bg-yellow-500";
      case "duplicate":
        return "bg-orange-500";
      case "unusual_amount":
        return "bg-red-500";
      case "uncategorized":
        return "bg-blue-500";
      default:
        return "bg-gray-500";
    }
  };

  return (
    <ScrollArea className="w-full rounded-md" style={{ maxHeight }}>
      <div className="space-y-3 pr-4">
        {transactions.map((transaction) => (
          <Card 
            key={transaction.id}
            className="cursor-pointer hover:bg-accent/50 transition-colors"
            onClick={() => handleTransactionClick(transaction.id)}
          >
            <CardContent className="p-4">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div className="flex items-start gap-3">
                  <AlertCircle className="h-5 w-5 text-yellow-500 mt-1 shrink-0" />
                  <div className="min-w-0 flex-1">
                    <h3 className="font-medium truncate">
                      {transaction.description ?? "No Description"}
                    </h3>
                    <p className="text-sm text-muted-foreground">
                      Amount: ${parseFloat(transaction.amount.toString()).toFixed(2)}
                    </p>
                    <p className="text-sm text-muted-foreground">
                      Date: {new Date(transaction.date).toLocaleDateString()}
                    </p>
                    <div className="flex flex-col gap-2 mt-2">
                      <div className="flex flex-wrap gap-2">
                        {transaction.flags?.map((flag) => (
                          <Badge key={`${transaction.id}-${flag}`} variant="secondary" className={getFlagColor(flag)}>
                            {flag}
                          </Badge>
                        ))}
                      </div>
                      {transaction.transactionCategories && transaction.transactionCategories.length > 0 && (
                        <div className="flex flex-wrap gap-2 items-center">
                          <span className="text-sm text-muted-foreground">Categories:</span>
                          {transaction.transactionCategories.map((tc) => (
                            <Badge key={`${transaction.id}-${tc.category.id}`} variant="outline">
                              {tc.category.name}
                            </Badge>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                </div>
                <div className="flex gap-2 sm:flex-shrink-0">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={(e) => {
                      e.stopPropagation();
                      handleTransactionClick(transaction.id);
                    }}
                  >
                    <Pencil className="mr-2 h-4 w-4" />
                    Edit
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={(e) => handleApprove(e, transaction.id)}
                    disabled={approveMutation.isPending || deleteMutation.isPending}
                  >
                    <Check className="mr-2 h-4 w-4" />
                    Approve
                  </Button>
                  <Button
                    variant="destructive"
                    size="sm"
                    onClick={(e) => handleDelete(e, transaction.id)}
                    disabled={approveMutation.isPending || deleteMutation.isPending}
                  >
                    <Trash2 className="mr-2 h-4 w-4" />
                    Delete
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </ScrollArea>
  );
} 