'use client';

import { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { 
  Table, 
  TableBody, 
  TableCell, 
  TableHead, 
  TableHeader, 
  TableRow 
} from "@/components/ui/table";
import { 
  Card, 
  CardContent, 
  CardDescription, 
  CardFooter, 
  CardHeader, 
  CardTitle 
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { 
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";
import { format } from 'date-fns';
import { Tag, Info, MoreVertical, Flag, AlertTriangle, Plus, Upload } from 'lucide-react';
import { toast } from 'sonner';

// Type definitions
interface Rule {
  id: number;
  condition_field: string;
  condition_operator: string;
  condition_value: string;
}

interface Category {
  id: number;
  name: string;
}

interface Transaction {
  id: number;
  date: string;
  description: string;
  amount: string;
  category_id: number | null;
  flagged: boolean;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
  category?: Category;
  applied_rules: Rule[];
}

interface Pagination {
  current_page: number;
  next_page: number | null;
  prev_page: number | null;
  total_pages: number;
  total_count: number;
}

interface ApiResponse {
  transactions: Transaction[];
  pagination: Pagination;
}

interface NewTransactionForm {
  date: string;
  description: string;
  amount: string;
  category_id: string;
  flagged: boolean;
}

// API functions
const api = {
  fetchTransactions: async () => {
    const response = await fetch('http://localhost:8000/api/v1/transactions');
    if (!response.ok) throw new Error('Network response was not ok');
    return response.json() as Promise<ApiResponse>;
  },
  
  createTransaction: async (newTransaction: NewTransactionForm) => {
    const response = await fetch('http://localhost:8000/api/v1/transactions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...newTransaction,
        amount: parseFloat(newTransaction.amount).toString(),
        category_id: newTransaction.category_id ? parseInt(newTransaction.category_id) : null
      }),
    });
    if (!response.ok) throw new Error('Failed to create transaction');
    return response.json();
  },
  
  importCSV: async (formData: FormData) => {
    const response = await fetch('http://localhost:8000/api/v1/transactions/import', {
      method: 'POST',
      body: formData,
    });
    if (!response.ok) throw new Error('Failed to import CSV');
    return response.json();
  },

  fetchCategories: async () => {
    const response = await fetch('http://localhost:8000/api/v1/categories');
    if (!response.ok) throw new Error('Failed to fetch categories');
    return response.json() as Promise<Category[]>;
  }
};

export default function TransactionsTable() {
  const queryClient = useQueryClient();
  const [isAddDialogOpen, setIsAddDialogOpen] = useState<boolean>(false);
  const [csvFile, setCsvFile] = useState<File | null>(null);
  const [isDragging, setIsDragging] = useState<boolean>(false);
  const [csvUploadStatus, setCsvUploadStatus] = useState<string>('');
  
  // Form state for new transaction
  const [newTransaction, setNewTransaction] = useState<NewTransactionForm>({
    date: format(new Date(), 'yyyy-MM-dd'),
    description: '',
    amount: '',
    category_id: '',
    flagged: false
  });

  // Queries
  const { 
    data: transactionsData, 
    isLoading: transactionsLoading, 
    error: transactionsError 
  } = useQuery({
    queryKey: ['transactions'],
    queryFn: api.fetchTransactions
  });

  const { 
    data: categories = [], 
    isLoading: categoriesLoading 
  } = useQuery({
    queryKey: ['categories'],
    queryFn: api.fetchCategories
  });

  // Mutations
  const createTransactionMutation = useMutation({
    mutationFn: api.createTransaction,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      setIsAddDialogOpen(false);
      toast('Transaction created successfully');
      resetForm();
    },
    onError: (error) => {
      toast('Error creating transaction');
      console.error(error);
    }
  });

  const importCSVMutation = useMutation({
    mutationFn: api.importCSV,
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      toast(`Successfully imported transactions`);
      resetCSVForm();
    },
    onError: (error) => {
      toast('Error importing CSV');
      console.error(error);
    }
  });

  // Helper functions
  const resetForm = () => {
    setNewTransaction({
      date: format(new Date(), 'yyyy-MM-dd'),
      description: '',
      amount: '',
      category_id: '',
      flagged: false
    });
  };

  const resetCSVForm = () => {
    setCsvFile(null);
    setCsvUploadStatus('');
    setIsAddDialogOpen(false);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  };

  const formatAmount = (amount: string) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(parseFloat(amount));
  };

  // Event handlers
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setNewTransaction(prev => ({ ...prev, [name]: value }));
  };

  const handleCheckboxChange = (checked: boolean) => {
    setNewTransaction(prev => ({ ...prev, flagged: checked }));
  };

  const handleCategoryChange = (value: string) => {
    setNewTransaction(prev => ({ ...prev, category_id: value }));
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setCsvFile(e.target.files[0]);
      setCsvUploadStatus(`Selected file: ${e.target.files[0].name}`);
    }
  };

  const handleDragOver = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      const file = e.dataTransfer.files[0];
      if (file.type === 'text/csv' || file.name.endsWith('.csv')) {
        setCsvFile(file);
        setCsvUploadStatus(`Selected file: ${file.name}`);
      } else {
        setCsvUploadStatus('Please upload a CSV file');
      }
    }
  };

  const handleSubmitTransaction = async (e: React.FormEvent) => {
    e.preventDefault();
    createTransactionMutation.mutate(newTransaction);
  };

  const handleSubmitCsv = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!csvFile) {
      setCsvUploadStatus('Please select a CSV file first');
      return;
    }
    const formData = new FormData();
    formData.append('file', csvFile);
    importCSVMutation.mutate(formData);
  };

  if (transactionsLoading || categoriesLoading) {
    return <div className="flex justify-center items-center h-64">Loading...</div>;
  }

  if (transactionsError) {
    return (
      <div className="flex flex-col items-center justify-center h-64 text-red-500">
        <AlertTriangle className="h-8 w-8 mb-2" />
        <p>Error loading transactions: {transactionsError instanceof Error ? transactionsError.message : 'Unknown error'}</p>
      </div>
    );
  }

  const transactions = transactionsData?.transactions || [];
  const pagination = transactionsData?.pagination;

  return (
    <Card className="w-full">
      <CardHeader className="flex flex-row items-center justify-between">
        <div>
          <CardTitle>Transactions</CardTitle>
          <CardDescription>
            Manage and view your recent financial transactions.
          </CardDescription>
        </div>
        <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
          <DialogTrigger asChild>
            <Button className="ml-auto">
              <Plus className="mr-2 h-4 w-4" /> Add Transaction
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[525px]">
            <DialogHeader>
              <DialogTitle>Add Transaction</DialogTitle>
              <DialogDescription>
                Create a new transaction manually or import from CSV.
              </DialogDescription>
            </DialogHeader>
            
            <Tabs defaultValue="manual" className="mt-4">
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="manual">Manual Entry</TabsTrigger>
                <TabsTrigger value="csv">Import CSV</TabsTrigger>
              </TabsList>
              
              <TabsContent value="manual">
                <form onSubmit={handleSubmitTransaction} className="space-y-4 mt-4">
                  <div className="space-y-2">
                    <Label htmlFor="date">Date</Label>
                    <Input
                      id="date"
                      name="date"
                      type="date"
                      value={newTransaction.date}
                      onChange={handleInputChange}
                      required
                    />
                  </div>
                  
                  <div className="space-y-2">
                    <Label htmlFor="description">Description</Label>
                    <Input
                      id="description"
                      name="description"
                      placeholder="Transaction description"
                      value={newTransaction.description}
                      onChange={handleInputChange}
                      required
                    />
                  </div>
                  
                  <div className="space-y-2">
                    <Label htmlFor="amount">Amount ($)</Label>
                    <Input
                      id="amount"
                      name="amount"
                      type="number"
                      step="0.01"
                      placeholder="0.00"
                      value={newTransaction.amount}
                      onChange={handleInputChange}
                      required
                    />
                  </div>
                  
                  <div className="space-y-2">
                    <Label htmlFor="category">Category</Label>
                    <Select
                      value={newTransaction.category_id}
                      onValueChange={handleCategoryChange}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="Select a category" />
                      </SelectTrigger>
                      <SelectContent>
                        {categories.map((category) => (
                          <SelectItem key={category.id} value={category.id.toString()}>
                            {category.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  
                  <div className="flex items-center space-x-2">
                    <Checkbox
                      id="flagged"
                      checked={newTransaction.flagged}
                      onCheckedChange={handleCheckboxChange}
                    />
                    <Label htmlFor="flagged">Flag this transaction</Label>
                  </div>
                  
                  <DialogFooter>
                    <Button 
                      type="submit" 
                      disabled={createTransactionMutation.isPending}
                    >
                      {createTransactionMutation.isPending ? 'Creating...' : 'Create Transaction'}
                    </Button>
                  </DialogFooter>
                </form>
              </TabsContent>
              
              <TabsContent value="csv">
                <form onSubmit={handleSubmitCsv} className="space-y-4 mt-4">
                  <div 
                    className={`border-2 border-dashed rounded-md p-6 text-center ${
                      isDragging ? 'border-primary bg-primary/10' : 'border-gray-300'
                    }`}
                    onDragOver={handleDragOver}
                    onDragLeave={handleDragLeave}
                    onDrop={handleDrop}
                  >
                    <Upload className="mx-auto h-8 w-8 text-gray-400 mb-2" />
                    <p>Drag and drop your CSV file here or</p>
                    <div className="mt-2">
                      <Label htmlFor="csvFile" className="cursor-pointer text-primary hover:underline">
                        Browse files
                      </Label>
                      <Input 
                        id="csvFile" 
                        type="file" 
                        accept=".csv" 
                        onChange={handleFileChange}
                        className="hidden" 
                      />
                    </div>
                    <p className="text-xs text-gray-500 mt-2">
                      CSV must include: date, description, amount, category, flagged
                    </p>
                    {csvUploadStatus && (
                      <p className={`mt-2 text-sm ${csvUploadStatus.includes('Error') ? 'text-red-500' : 'text-green-500'}`}>
                        {csvUploadStatus}
                      </p>
                    )}
                  </div>
                  
                  <DialogFooter>
                    <Button 
                      type="submit" 
                      disabled={!csvFile || importCSVMutation.isPending}
                    >
                      {importCSVMutation.isPending ? 'Importing...' : 'Upload CSV'}
                    </Button>
                  </DialogFooter>
                </form>
              </TabsContent>
            </Tabs>
          </DialogContent>
        </Dialog>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Date</TableHead>
              <TableHead>Description</TableHead>
              <TableHead>Amount</TableHead>
              <TableHead>Category</TableHead>
              <TableHead>Rules</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {transactions.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} className="text-center">
                  No transactions found. Add your first transaction!
                </TableCell>
              </TableRow>
            ) : (
              transactions.map((transaction) => (
                <TableRow key={transaction.id}>
                  <TableCell>{formatDate(transaction.date)}</TableCell>
                  <TableCell className="font-medium">{transaction.description}</TableCell>
                  <TableCell>{formatAmount(transaction.amount)}</TableCell>
                  <TableCell>
                    {transaction.category ? (
                      <Badge variant="outline" className="bg-slate-100">
                        <Tag className="h-3 w-3 mr-1" />
                        {transaction.category.name}
                      </Badge>
                    ) : "-"}
                  </TableCell>
                  <TableCell>
                    {transaction.applied_rules.length > 0 ? (
                      <TooltipProvider>
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Badge variant="secondary" className="cursor-help">
                              {transaction.applied_rules.length} rule{transaction.applied_rules.length !== 1 ? 's' : ''}
                            </Badge>
                          </TooltipTrigger>
                          <TooltipContent>
                            <ul className="list-disc list-inside">
                              {transaction.applied_rules.map((rule) => (
                                <li key={rule.id}>
                                  {rule.condition_field} {rule.condition_operator} "{rule.condition_value}"
                                </li>
                              ))}
                            </ul>
                          </TooltipContent>
                        </Tooltip>
                      </TooltipProvider>
                    ) : "-"}
                  </TableCell>
                  <TableCell className="text-right">
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="icon">
                          <MoreVertical className="h-4 w-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuLabel>Actions</DropdownMenuLabel>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem>
                          <Info className="h-4 w-4 mr-2" /> View Details
                        </DropdownMenuItem>
                        <DropdownMenuItem>
                          <Tag className="h-4 w-4 mr-2" /> Assign Category
                        </DropdownMenuItem>
                        <DropdownMenuItem>
                          <Flag className="h-4 w-4 mr-2" /> {transaction.flagged ? 'Unflag' : 'Flag'} Transaction
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </CardContent>
      <CardFooter className="flex justify-between">
        <div>
          {pagination && (
            <p className="text-sm text-muted-foreground">
              Showing {transactions.length} of {pagination.total_count} transactions
            </p>
          )}
        </div>
        <div className="flex gap-2">
          <Button
            variant="outline"
            disabled={!pagination?.prev_page}
            onClick={() => {/* Add pagination logic here */}}
          >
            Previous
          </Button>
          <Button
            variant="outline"
            disabled={!pagination?.next_page}
            onClick={() => {/* Add pagination logic here */}}
          >
            Next
          </Button>
        </div>
      </CardFooter>
    </Card>
  );
}