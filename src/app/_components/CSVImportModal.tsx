"use client";

import { useState } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { api } from "~/trpc/react";
import { Download, Upload, X, AlertCircle, Check } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Input } from "@/components/ui/input";

type CSVTransaction = {
  id: string;
  date: string;
  description: string;
  amount: string;
  category?: string;
  isValid: boolean;
  errors: string[];
  isDuplicate: boolean;
};

interface CSVImportModalProps {
  isOpen: boolean;
  onClose: () => void;
  userId: string;
}

export function CSVImportModal({ isOpen, onClose, userId }: CSVImportModalProps) {
  const [transactions, setTransactions] = useState<CSVTransaction[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const utils = api.useUtils();

  const importMutation = api.transaction.importFromCsv.useMutation({
    onSuccess: async () => {
      // Invalidate both queries to ensure all transaction lists are updated
      await Promise.all([
        utils.transaction.getAll.invalidate({ userId }),
        utils.transaction.getNeedingReview.invalidate({ userId })
      ]);
      onClose();
    },
    onError: (error) => {
      console.error("Error importing transactions:", error);
    }
  });

  const downloadTemplate = () => {
    const template = "Date,Description,Amount,Category\n";
    const blob = new Blob([template], { type: "text/csv" });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "transaction_template.csv";
    a.click();
    window.URL.revokeObjectURL(url);
  };

  const validateTransactions = (csvData: CSVTransaction[]) => {
    return csvData.map(transaction => {
      const errors: string[] = [];
      
      // Check required fields
      if (!transaction.date) errors.push("Missing date");
      if (!transaction.description) errors.push("Missing description");
      if (!transaction.amount) errors.push("Missing amount");
      
      // Validate date format
      const dateValid = !isNaN(Date.parse(transaction.date));
      if (!dateValid) errors.push("Invalid date format");
      
      // Validate amount format
      const amountValid = !isNaN(parseFloat(transaction.amount));
      if (!amountValid) errors.push("Invalid amount format");

      // Check for duplicates
      const isDuplicate = csvData.some(t => 
        t !== transaction &&
        t.date === transaction.date &&
        t.description === transaction.description &&
        t.amount === transaction.amount
      );

      return {
        ...transaction,
        isValid: errors.length === 0,
        errors,
        isDuplicate,
      };
    });
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setIsProcessing(true);
    const reader = new FileReader();

    reader.onload = async (event) => {
      const csvText = event.target?.result as string;
      const lines = csvText.split("\n");
      const headers = lines[0]!.split(",").map(h => h.trim().toLowerCase());

      const parsedTransactions: CSVTransaction[] = lines
        .slice(1)
        .filter(line => line.trim())
        .map(line => {
          const values = line.split(",").map(v => v.trim());
          return {
            id: crypto.randomUUID(),
            date: values[headers.indexOf("date")] ?? "",
            description: values[headers.indexOf("description")] ?? "",
            amount: values[headers.indexOf("amount")] ?? "",
            category: values[headers.indexOf("category")] ?? undefined,
            isValid: true,
            errors: [],
            isDuplicate: false,
          };
        });

      const validatedTransactions = validateTransactions(parsedTransactions);
      setTransactions(validatedTransactions);
      setIsProcessing(false);
    };

    reader.readAsText(file);
  };

  const handleImport = () => {
    const validTransactions = transactions
      .filter(t => t.isValid && !t.isDuplicate)
      .map(t => ({
        date: new Date(t.date),
        description: t.description,
        amount: parseFloat(t.amount),
        categoryIds: t.category ? [t.category] : undefined,
      }));

    importMutation.mutate({
      userId,
      transactions: validTransactions,
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="max-w-[90vw] w-full max-h-[85vh] flex flex-col p-0">
        <DialogHeader className="px-6 py-4 border-b">
          <DialogTitle>Import Transactions</DialogTitle>
        </DialogHeader>

        <div className="flex-1 flex flex-col min-h-0 p-6">
          <div className="flex justify-between items-center mb-4">
            <Button onClick={downloadTemplate}>
              <Download className="mr-2 h-4 w-4" />
              Download Template
            </Button>
            <Input
              type="file"
              accept=".csv"
              onChange={handleFileUpload}
              className="max-w-xs"
            />
          </div>

          {isProcessing && (
            <div className="text-center py-4">Processing CSV file...</div>
          )}

          {transactions.length > 0 && (
            <div className="flex-1 flex flex-col min-h-0">
              <div className="flex-1 overflow-y-auto rounded-md border">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead className="sticky top-0 bg-background z-10 w-[100px] text-center">Status</TableHead>
                      <TableHead className="sticky top-0 bg-background z-10 w-[140px]">Date</TableHead>
                      <TableHead className="sticky top-0 bg-background z-10 min-w-[400px]">Description</TableHead>
                      <TableHead className="sticky top-0 bg-background z-10 w-[140px] text-right">Amount</TableHead>
                      <TableHead className="sticky top-0 bg-background z-10 w-[200px]">Category</TableHead>
                      <TableHead className="sticky top-0 bg-background z-10 w-[100px] text-center">Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody className="overflow-y-auto">
                    {transactions.map((transaction) => (
                      <TableRow key={transaction.id}>
                        <TableCell className="text-center">
                          {transaction.isDuplicate ? (
                            <Badge variant="destructive" className="w-full">Duplicate</Badge>
                          ) : transaction.isValid ? (
                            <Check className="h-4 w-4 text-green-500 mx-auto" />
                          ) : (
                            <AlertCircle className="h-4 w-4 text-red-500 mx-auto" />
                          )}
                        </TableCell>
                        <TableCell className={!transaction.date ? "text-red-500" : ""}>
                          {transaction.date || "Missing"}
                        </TableCell>
                        <TableCell className={`${!transaction.description ? "text-red-500" : ""} break-words`}>
                          {transaction.description || "Missing"}
                        </TableCell>
                        <TableCell className={`text-right ${!transaction.amount ? "text-red-500" : ""}`}>
                          {transaction.amount || "Missing"}
                        </TableCell>
                        <TableCell>{transaction.category ?? "None"}</TableCell>
                        <TableCell className="text-center">
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => {
                              setTransactions(transactions.filter(t => t.id !== transaction.id));
                            }}
                          >
                            <X className="h-4 w-4" />
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>

              <div className="flex justify-end space-x-2 pt-4 mt-4 border-t">
                <Button variant="outline" onClick={onClose}>
                  Cancel
                </Button>
                <Button
                  onClick={handleImport}
                  disabled={!transactions.some(t => t.isValid && !t.isDuplicate)}
                >
                  Import Valid Transactions
                </Button>
              </div>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
} 