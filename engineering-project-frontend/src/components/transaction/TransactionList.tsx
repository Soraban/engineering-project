import React from "react";
import { FixedSizeList as VirtualizedList } from "react-window";
import { Transaction } from "@/types/transaction";
import { TrashIcon } from "@/assets/icons";

interface TransactionListProps {
  transactions: Transaction[];
  selectedIds: string[];
  deleteTransaction: (id: string) => void;
  deleteTransactions: (ids: string[]) => void;
  toggleSelect: (id: string) => void;
  selectAll: () => void;
}

const TransactionList = ({
  transactions,
  deleteTransaction,
  selectedIds,
  toggleSelect,
  selectAll,
}: TransactionListProps) => {
  const Row = ({
    index,
    style,
  }: {
    index: number;
    style: React.CSSProperties;
  }) => {
    const transaction = transactions[index];
    const isSelected = selectedIds.includes(transaction.id);

    return (
      <div
        style={style}
        className="grid grid-cols-8 items-center border-b border-gray-300 px-4 py-2 gap-4 text-gray-200"
      >
        <div className="w-[10px]">
          <input
            type="checkbox"
            checked={isSelected}
            onChange={() => toggleSelect(transaction.id)}
          />
        </div>
        <div className="truncate">{transaction.id}</div>
        <div className="truncate">
          {new Date(transaction.date).toLocaleDateString()}
        </div>
        <div className="truncate">{transaction.description}</div>
        <div className="truncate">${transaction.amount.toFixed(2)}</div>
        <div className="truncate">{transaction.category || "N/A"}</div>
        <div className="truncate">{transaction.isFlagged ? "Yes" : "No"}</div>
        <div>
          <TrashIcon
            onClick={() => deleteTransaction(transaction.id)}
            className="cursor-pointer hover:bg-gray-600 rounded-md"
          />
        </div>
      </div>
    );
  };

  return (
    <div className="w-full flex flex-col gap-4">
      {/* Table Header */}
      <div className="grid grid-cols-8 items-center border-b border-gray-300 bg-gray-600 px-4 py-2 font-semibold gap-4 text-gray-200">
        <div className="w-[10px]">
          <input
            type="checkbox"
            checked={selectedIds.length === transactions.length}
            onChange={selectAll}
          />
        </div>
        <div>ID</div>
        <div>Date</div>
        <div>Description</div>
        <div>Amount</div>
        <div>Category</div>
        <div>Flagged</div>
        <div></div>
      </div>

      {/* Virtualized Rows */}
      <VirtualizedList
        height={500}
        itemCount={transactions.length}
        itemSize={65}
        width="100%"
      >
        {Row}
      </VirtualizedList>
    </div>
  );
};

export default TransactionList;
