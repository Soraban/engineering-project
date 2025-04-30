export interface Transaction {
  id: number;
  date: string;
  description: string;
  amount: string | number;
  category_id: number | null;  // Add this field
  category?: {
    id: number;
    name: string;
  };
  flagged: boolean;
  metadata?: Record<string, any>;  // Add this field
  created_at: string;  // Add this field
  updated_at: string;  // Add this field
  applied_rules?: Array<{
    id: number;
    condition_field: string;
    condition_operator: string;
    condition_value: string;
  }>;
}

export interface TransactionResponse {
  transactions: Transaction[];
  pagination: {
    current_page: number;
    next_page: number | null;
    prev_page: number | null;
    total_pages: number;
    total_count: number;
  };
}

export interface CreateTransactionData {
  date: string;
  description: string;
  amount: number;
  category?: number;  // This is correct as category_id
  flagged?: boolean;
}