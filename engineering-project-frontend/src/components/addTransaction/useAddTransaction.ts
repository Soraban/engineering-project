import axios from "axios";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { API_URL } from "@/constants/url";

interface Transaction {
  id?: string;
  description: string;
  amount: number;
  date: string;
  category: string;
}

export const useAddTransaction = (transaction?: Transaction) => {
  const router = useRouter();

  const [description, setDescription] = useState<string>(
    transaction?.description || ""
  );
  const [amount, setAmount] = useState<number | string>(
    transaction?.amount || 0
  );
  const [date, setDate] = useState<string>(transaction?.date || "");
  const [category, setCategory] = useState<string>(transaction?.category || "");

  const redirectToHome = () => router.push("/");

  const handleBack = redirectToHome;

  const handleAddTransaction = async () => {
    try {
      await axios.post(`${API_URL}/transactions`, {
        description,
        amount,
        date,
        category,
      });
      redirectToHome();
    } catch (error) {
      console.error("Error adding transaction:", error);
    }
  };

  const handleEditTransaction = async () => {
    if (!transaction?.id) return;
    try {
      await axios.put(`${API_URL}/transactions/${transaction.id}`, {
        description,
        amount,
        date,
        category,
      });
      redirectToHome();
    } catch (error) {
      console.error("Error updating transaction:", error);
    }
  };

  return {
    description,
    setDescription,
    amount,
    setAmount,
    date,
    setDate,
    category,
    setCategory,
    handleAddTransaction,
    handleEditTransaction,
    handleBack,
  };
};
