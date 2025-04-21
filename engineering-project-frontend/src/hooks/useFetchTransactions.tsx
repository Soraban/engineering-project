import { useState, useCallback } from "react";
import axios from "axios";
import { API_URL } from "@/constants/url";
import { Transaction } from "@/types/transaction";

export const useFetchTransactions = () => {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState<boolean>(false);

  const fetchTransactions = useCallback(async (): Promise<Transaction[]> => {
    try {
      setLoading(true);
      const { data } = await axios.get<Transaction[]>(
        `${API_URL}/transactions`
      );
      setTransactions(data);
      return data;
    } catch (error) {
      console.error("Error fetching transactions", error);
      return [];
    } finally {
      setLoading(false);
    }
  }, []);

  return { transactions, loading, fetchTransactions };
};
