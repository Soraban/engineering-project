"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ReviewList } from "~/app/_components/ReviewList";
import { useUser } from "@clerk/nextjs";
import { useTransactionFlagging } from "~/hooks/useTransactionFlagging";
import { Loader2 } from "lucide-react";

export default function ReviewsPage() {
  const { user } = useUser();
  
  // Use the transaction flagging hook and get its loading state
  const { isProcessing } = useTransactionFlagging();

  if (!user) return null;

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <div className="flex items-center gap-4">
          <h1 className="text-3xl font-bold">Review Dashboard</h1>
          {isProcessing && (
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Loader2 className="h-4 w-4 animate-spin" />
              <span>Processing flagged transactions...</span>
            </div>
          )}
        </div>
      </div>

      <div className="grid gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Flagged Transactions</CardTitle>
          </CardHeader>
          <CardContent>
            <ReviewList userId={user.id} />
          </CardContent>
        </Card>
      </div>
    </div>
  );
} 