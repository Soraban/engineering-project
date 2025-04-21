import { useState } from "react";
import axios from "axios";
import { API_URL } from "@/constants/url";
import { useRouter } from "next/navigation";
import { useFetchTransactions } from "@/hooks/useFetchTransactions";

export const useTransactionActions = (
  transactionsInitial: {
    id: string;
    description: string;
    amount: number;
    date: string;
    category: string;
  }[]
) => {
  const router = useRouter();
  const { fetchTransactions } = useFetchTransactions();

  const [selectedCategory, setSelectedCategory] = useState<string>("");
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [transactions, setTransactions] = useState(transactionsInitial);
  const [transactionIdsToDelete, setTransactionIdsToDelete] = useState<
    string[]
  >([]);
  const [transactionIdToDelete, setTransactionIdToDelete] = useState<
    string | null
  >(null);
  const [csvError, setCsvError] = useState<string | null>(null);

  const handleCsvFileChange = async (
    e: React.ChangeEvent<HTMLInputElement>
  ) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const formData = new FormData();
      formData.append("csvFile", file);

      await axios.post(`${API_URL}/transactions/bulk`, formData, {
        headers: {
          "Content-Type": "multipart/form-data",
        },
      });

      setCsvError(null);
      const updatedTransactions = await fetchTransactions();
      setTransactions(updatedTransactions);
    } catch (error) {
      alert("Something went wrong while processing the file.");
      console.error("Something went wrong while processing the file:", error);
    }
  };

  const openDeleteModal = (id: string) => {
    setTransactionIdToDelete(id);
  };

  const closeDeleteModal = () => {
    setTransactionIdToDelete(null);
  };

  const handleDeleteConfirm = async (id: string) => {
    const previousTransactions = [...transactions];
    try {
      await axios.delete(`${API_URL}/transactions/${id}`);
      setTransactions((prevTransactions) =>
        prevTransactions.filter((t) => t.id !== id)
      );
      setTransactionIdToDelete(null);
    } catch (error) {
      console.error("Error deleting transaction:", error);
      setTransactions(previousTransactions);
    }
  };

  const handleBulkDeleteConfirm = async (ids: string[]) => {
    const previousTransactions = [...transactions];
    try {
      await axios.post(`${API_URL}/transactions/bulk-delete`, { ids });
      setTransactions((prevTransactions) =>
        prevTransactions.filter((t) => !ids.includes(t.id))
      );
      setTransactionIdsToDelete([]);
      setSelectedIds([]);
    } catch (error) {
      console.error("Error deleting multiple transactions:", error);
      setTransactions(previousTransactions);
    }
  };

  const handleCreate = () => router.push("create");

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) =>
      prev.includes(id) ? prev.filter((i) => i !== id) : [...prev, id]
    );
  };

  const selectAll = () => {
    if (selectedIds.length === transactions.length) {
      setSelectedIds([]);
    } else {
      setSelectedIds(transactions.map((tx) => tx.id));
    }
  };

  const handleApplyCategory = async () => {
    if (selectedCategory && selectedIds.length > 0) {
      try {
        await axios.post(`${API_URL}/transactions/bulk-categorize`, {
          category: selectedCategory,
          transactionIds: selectedIds,
        });
        const updatedTransactions = await fetchTransactions();
        setTransactions(updatedTransactions);
        setSelectedCategory("");
        setSelectedIds([]);
      } catch (error) {
        console.error("Error bulk categorizing:", error);
      }
    }
  };

  return {
    transactionIdToDelete,
    transactionIdsToDelete,
    setTransactionIdsToDelete,
    setTransactionIdToDelete,
    setTransactions,
    transactions,
    openDeleteModal,
    closeDeleteModal,
    handleApplyCategory,
    handleDeleteConfirm,
    handleBulkDeleteConfirm,
    handleCsvFileChange,
    handleCreate,
    csvError,
    toggleSelect,
    selectAll,
    selectedIds,
    selectedCategory,
    setSelectedCategory,
  };
};
