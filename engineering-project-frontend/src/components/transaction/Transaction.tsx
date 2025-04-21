"use client";
import TransactionList from "./TransactionList";
import EmptyList from "../common/emptyList/EmptyList";
import Button from "../common/button/Button";
import DeleteModal from "../common/modals/DeleteModal";
import { useTransactionActions } from "./useTransactionActions";
import { Transaction as TransactionType } from "@/types/transaction";
import { TrashIcon } from "@/assets/icons";
import CategorySelect from "./CategorySelect";

interface TransactionProps {
  transactions: TransactionType[];
}

const Transaction = ({
  transactions: transactionsInitial,
}: TransactionProps) => {
  const {
    transactionIdToDelete,
    setTransactionIdToDelete,
    transactionIdsToDelete,
    setTransactionIdsToDelete,
    transactions,
    handleApplyCategory,
    handleDeleteConfirm,
    handleBulkDeleteConfirm,
    handleCreate,
    handleCsvFileChange,
    toggleSelect,
    selectAll,
    selectedIds,
    selectedCategory,
    setSelectedCategory,
  } = useTransactionActions(transactionsInitial);

  return (
    <>
      <div className="w-full flex flex-col justify-center items-end px-4">
        <div className="flex justify-between items-center mb-4 gap-4 w-full">
          <div className="flex justify-between items-center gap-2 ml-[10px]">
            {!!transactions.length && (
              <>
                <TrashIcon
                  onClick={() => setTransactionIdsToDelete(selectedIds)}
                  className="cursor-pointer hover:bg-gray-600 rounded-md"
                />
                <div className="text-gray-200 font-semibold text-sm">
                  Selected: {selectedIds?.length}
                </div>
                <CategorySelect
                  selectedCategory={selectedCategory}
                  setSelectedCategory={setSelectedCategory}
                  handleApplyCategory={handleApplyCategory}
                  selectedIds={selectedIds}
                />
              </>
            )}
          </div>
          <div className="flex gap-4">
            <Button label="Create Transaction" onClick={handleCreate} />
            <label className="bg-green-500 hover:opacity-[80%] text-white font-semibold py-2 px-4 rounded cursor-pointer flex items-center">
              Import CSV
              <input
                type="file"
                accept=".csv"
                onChange={handleCsvFileChange}
                className="hidden"
              />
            </label>
          </div>
        </div>

        <div className="w-full">
          {!transactions.length ? (
            <EmptyList />
          ) : (
            <TransactionList
              selectedIds={selectedIds}
              toggleSelect={toggleSelect}
              selectAll={selectAll}
              transactions={transactions}
              deleteTransaction={setTransactionIdToDelete}
              deleteTransactions={setTransactionIdsToDelete}
            />
          )}
        </div>
      </div>

      {/* Single delete modal */}
      {transactionIdToDelete && (
        <DeleteModal
          isOpen
          onClose={() => setTransactionIdToDelete(null)}
          onConfirm={() => handleDeleteConfirm(transactionIdToDelete)}
          text={`Are you sure you want to delete the transaction with ID: ${transactionIdToDelete}?`}
        />
      )}

      {/* Bulk delete modal */}
      {transactionIdsToDelete.length > 0 && (
        <DeleteModal
          isOpen
          onClose={() => setTransactionIdsToDelete([])}
          onConfirm={() => handleBulkDeleteConfirm(transactionIdsToDelete)}
          text={`Are you sure you want to delete ${transactionIdsToDelete.length} selected transactions?`}
        />
      )}
    </>
  );
};

export default Transaction;
