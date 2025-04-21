"use client";

import React from "react";
import { ArrowLeft as BackButton } from "@/assets/icons";
import Button from "../common/button/Button";
import Label from "../common/label/Label";
import Input from "../common/input/Input";
import { useAddTransaction } from "./useAddTransaction";
import { ONLY_NUMERIC_WITH_DECIMAL_REGEX } from "@/constants/regex";

interface AddTransactionProps {
  transaction?: {
    id?: string;
    description: string;
    amount: number;
    date: string;
    category: string;
  };
}

const AddEditTransaction: React.FC<AddTransactionProps> = ({ transaction }) => {
  const {
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
  } = useAddTransaction(transaction);

  return (
    <div className="w-full md:w-[736px] flex flex-col justify-between mt-2 px-4 md:px-0">
      <div className="flex flex-col space-y-3">
        <BackButton onClick={handleBack} className="cursor-pointer mb-10" />

        <Label text="Description" />
        <Input
          type="text"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Ex. Starbucks"
          dark
        />

        <Label text="Amount" />
        <Input
          type="text"
          value={amount}
          onChange={(e) => {
            const { value } = e.target;
            if (ONLY_NUMERIC_WITH_DECIMAL_REGEX.test(value)) {
              setAmount(value);
            }
          }}
          placeholder="Ex. 5.75"
          dark
        />

        <Label text="Date" />
        <Input
          type="date"
          value={date}
          onChange={(e) => setDate(e.target.value)}
          dark
        />

        <Label text="Category" />
        <Input
          type="text"
          value={category}
          onChange={(e) => setCategory(e.target.value)}
          placeholder="Ex. Coffee"
          dark
        />

        <Button
          label={transaction ? "Save Transaction" : "Add Transaction"}
          onClick={transaction ? handleEditTransaction : handleAddTransaction}
        />
      </div>
    </div>
  );
};

export default AddEditTransaction;
