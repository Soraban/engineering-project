import { useState } from "react";
import { api } from "~/trpc/react";
import { format } from "date-fns";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { transactions, transactionCategories, categories } from "~/server/db/schema";
import { flagsEnum } from "~/server/db/schema";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { toast } from "sonner";

type Transaction = typeof transactions.$inferSelect & {
  flags: Array<(typeof flagsEnum.enumValues)[number]> | null;
  categories: {
    id: string;
    name: string;
  }[];
};

export function TransactionList({ userId }: { userId: string }) {
  const [startDate, setStartDate] = useState<string>("");
  const [endDate, setEndDate] = useState<string>("");
  const [categoryId, setCategoryId] = useState<string>("all");
  const [flaggedStatus, setFlaggedStatus] = useState<string>("all");
  const [selectedTransaction, setSelectedTransaction] = useState<Transaction | null>(null);
  const [selectedTransactions, setSelectedTransactions] = useState<Set<string>>(new Set());
  const [bulkCategoryId, setBulkCategoryId] = useState<string>("");
  const [isBulkDialogOpen, setIsBulkDialogOpen] = useState(false);

  const utils = api.useUtils();
  const { data: categories } = api.category.getAll.useQuery({ userId });
  const { data: transactions, isLoading } = api.transaction.getAll.useQuery({
    userId,
    startDate: startDate ? new Date(startDate) : undefined,
    endDate: endDate ? new Date(endDate) : undefined,
    categoryId: categoryId === "all" ? undefined : categoryId,
    isFlagged: flaggedStatus === "all" ? undefined : flaggedStatus === "true",
  });

  const bulkCategorizeMutation = api.transaction.bulkCategorize.useMutation({
    onSuccess: () => {
      toast.success("Transactions categorized successfully");
      setSelectedTransactions(new Set());
      setBulkCategoryId("");
      setIsBulkDialogOpen(false);
      void utils.transaction.getAll.invalidate();
    },
    onError: (error) => {
      toast.error("Failed to categorize transactions: " + error.message);
    },
  });

  const handleBulkCategorize = () => {
    if (selectedTransactions.size === 0) {
      toast.error("Please select at least one transaction");
      return;
    }
    if (!bulkCategoryId) {
      toast.error("Please select a category");
      return;
    }

    bulkCategorizeMutation.mutate({
      userId,
      transactionIds: Array.from(selectedTransactions),
      categoryIds: [bulkCategoryId],
    });
  };

  const toggleTransactionSelection = (transactionId: string) => {
    const newSelected = new Set(selectedTransactions);
    if (newSelected.has(transactionId)) {
      newSelected.delete(transactionId);
    } else {
      newSelected.add(transactionId);
    }
    setSelectedTransactions(newSelected);
  };

  return (
    <>
      <Card className="flex flex-col h-full">
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>Transactions</CardTitle>
          <Button
            variant="outline"
            onClick={() => setIsBulkDialogOpen(true)}
            disabled={selectedTransactions.size === 0}
          >
            Bulk Categorize ({selectedTransactions.size})
          </Button>
        </CardHeader>
        <CardContent className="flex flex-col flex-grow space-y-4">
          <div className="grid gap-4 md:grid-cols-4">
            <div className="space-y-2">
              <Label htmlFor="startDate">Start Date</Label>
              <Input
                id="startDate"
                type="date"
                value={startDate}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setStartDate(e.target.value)}
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="endDate">End Date</Label>
              <Input
                id="endDate"
                type="date"
                value={endDate}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setEndDate(e.target.value)}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="category">Category</Label>
              <Select value={categoryId} onValueChange={setCategoryId}>
                <SelectTrigger>
                  <SelectValue placeholder="All Categories" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Categories</SelectItem>
                  {categories?.map((category) => (
                    <SelectItem key={category.id} value={category.id}>
                      {category.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="flagged">Status</Label>
              <Select 
                value={flaggedStatus}
                onValueChange={setFlaggedStatus}
              >
                <SelectTrigger>
                  <SelectValue placeholder="All Transactions" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Transactions</SelectItem>
                  <SelectItem value="true">Flagged</SelectItem>
                  <SelectItem value="false">Not Flagged</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          {isLoading ? (
            <div className="text-center py-4">Loading transactions...</div>
          ) : (
            <ScrollArea className="flex-grow">
              <div className="space-y-2 pr-4">
                {transactions?.map((transaction: Transaction) => (
                  <div
                    key={transaction.id}
                    className="flex items-center gap-2"
                  >
                    <Checkbox
                      checked={selectedTransactions.has(transaction.id)}
                      onCheckedChange={() => toggleTransactionSelection(transaction.id)}
                    />
                    <div
                      onClick={() => setSelectedTransaction(transaction)}
                      className="cursor-pointer flex-grow"
                    >
                      <Card className="hover:bg-accent transition-colors">
                        <CardContent className="p-4">
                          <div className="flex justify-between">
                            <div>
                              <p className="font-semibold">{transaction.description}</p>
                              <p className="text-sm text-muted-foreground">
                                {format(new Date(transaction.date), "MMM d, yyyy")}
                              </p>
                            </div>
                            <div className="text-right">
                              <p className="font-semibold">${parseFloat(transaction.amount).toFixed(2)}</p>
                              <div className="flex gap-1 justify-end flex-wrap">
                                {transaction.categories?.length > 0 ? (
                                  transaction.categories.map(category => (
                                    <Badge key={category.id} variant="secondary">
                                      {category.name}
                                    </Badge>
                                  ))
                                ) : (
                                  <Badge variant="outline">Uncategorized</Badge>
                                )}
                              </div>
                            </div>
                          </div>
                          {transaction.isFlagged && transaction.flags && transaction.flags.length > 0 && (
                            <div className="mt-2 flex gap-1 flex-wrap">
                              {transaction.flags.map((flag) => (
                                <Badge key={`${transaction.id}-${flag}`} variant="destructive">
                                  {flag}
                                </Badge>
                              ))}
                            </div>
                          )}
                        </CardContent>
                      </Card>
                    </div>
                  </div>
                ))}
              </div>
            </ScrollArea>
          )}
        </CardContent>
      </Card>

      <Dialog open={!!selectedTransaction} onOpenChange={(open) => !open && setSelectedTransaction(null)}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Transaction Details</DialogTitle>
          </DialogHeader>
          {selectedTransaction && (
            <div className="space-y-4">
              <div className="space-y-2">
                <Label>Description</Label>
                <p className="text-sm">{selectedTransaction.description}</p>
              </div>
              <div className="space-y-2">
                <Label>Amount</Label>
                <p className="text-sm">${parseFloat(selectedTransaction.amount).toFixed(2)}</p>
              </div>
              <div className="space-y-2">
                <Label>Date</Label>
                <p className="text-sm">{format(new Date(selectedTransaction.date), "MMMM d, yyyy")}</p>
              </div>
              <div className="space-y-2">
                <Label>Categories</Label>
                <div className="flex gap-1 flex-wrap">
                  {selectedTransaction.categories?.length > 0 ? (
                    selectedTransaction.categories.map(category => (
                      <Badge key={category.id} variant="secondary">
                        {category.name}
                      </Badge>
                    ))
                  ) : (
                    <Badge variant="outline">Uncategorized</Badge>
                  )}
                </div>
              </div>
              {selectedTransaction.flags && selectedTransaction.flags.length > 0 && (
                <div className="space-y-2">
                  <Label>Flags</Label>
                  <div className="flex gap-1 flex-wrap">
                    {selectedTransaction.flags.map((flag) => (
                      <Badge key={`${selectedTransaction.id}-${flag}`} variant="destructive">
                        {flag}
                      </Badge>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </DialogContent>
      </Dialog>

      <Dialog open={isBulkDialogOpen} onOpenChange={setIsBulkDialogOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Bulk Categorize Transactions</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label>Selected Transactions: {selectedTransactions.size}</Label>
            </div>
            <div className="space-y-2">
              <Label>Category</Label>
              <Select value={bulkCategoryId} onValueChange={setBulkCategoryId}>
                <SelectTrigger>
                  <SelectValue placeholder="Select a category" />
                </SelectTrigger>
                <SelectContent>
                  {categories?.map((category) => (
                    <SelectItem key={category.id} value={category.id}>
                      {category.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex justify-end">
              <Button
                onClick={handleBulkCategorize}
                disabled={!bulkCategoryId || bulkCategorizeMutation.isPending}
              >
                {bulkCategorizeMutation.isPending ? "Applying..." : "Apply Category"}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}