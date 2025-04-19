"use client";

import { Button } from "@/components/ui/button";
import { FileText, Upload, Loader2 } from "lucide-react";
import { redirect, useRouter } from "next/navigation";
import { useState } from "react";
import { CSVImportModal } from "~/app/_components/CSVImportModal";
import { TransactionList } from "~/app/_components/TransactionList";
import { useUser } from "@clerk/nextjs";
import { useTransactionFlagging } from "~/hooks/useTransactionFlagging";

export default function TransactionsPage() {
  const router = useRouter();
  const { user } = useUser();
  const [isImportModalOpen, setIsImportModalOpen] = useState(false);
  
  // Use the transaction flagging hook and get its loading state
  const { isProcessing } = useTransactionFlagging();

  const handleAddTransaction = () => {
    router.push(`/transactions/new`);
  };

  if (!user?.id) {
    redirect("/sign-in");
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <div className="flex items-center gap-4">
          <h1 className="text-3xl font-bold">Transactions</h1>
          {isProcessing && (
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Loader2 className="h-4 w-4 animate-spin" />
              <span>Processing flagged transactions...</span>
            </div>
          )}
        </div>
        <div className="flex gap-4">
          <Button onClick={() => setIsImportModalOpen(true)}>
            <Upload className="mr-2 h-4 w-4" />
            Import CSV
          </Button>
          <Button onClick={handleAddTransaction}>
            <FileText className="mr-2 h-4 w-4" />
            Add Transaction
          </Button>
        </div>
      </div>

      <TransactionList userId={user.id} />

      <CSVImportModal
        isOpen={isImportModalOpen}
        onClose={() => setIsImportModalOpen(false)}
        userId={user.id}
      />
    </div>
  );
}
