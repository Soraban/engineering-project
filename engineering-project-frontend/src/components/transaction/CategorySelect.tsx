import React from "react";

type CategorySelectProps = {
  selectedCategory: string;
  setSelectedCategory: (category: string) => void;
  handleApplyCategory: () => void;
  selectedIds: string[];
};

const CategorySelect: React.FC<CategorySelectProps> = ({
  selectedCategory,
  setSelectedCategory,
  handleApplyCategory,
  selectedIds,
}) => {
  return (
    <div className="flex items-center gap-4 px-4">
      <select
        value={selectedCategory}
        onChange={(e) => setSelectedCategory(e.target.value)}
        className="bg-gray-600 text-gray-200 p-2 rounded text-sm"
      >
        <option value="">Select category</option>
        <option value="Shopping">Shopping</option>
        <option value="Groceries">Groceries</option>
        <option value="Utilities">Utilities</option>
        <option value="Rent">Rent</option>
        <option value="Salary">Salary</option>
        <option value="Entertainment">Entertainment</option>
        <option value="Other">Other</option>
      </select>
      <button
        onClick={handleApplyCategory}
        disabled={!selectedCategory || selectedIds.length === 0}
        className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded disabled:opacity-50 text-sm"
      >
        Apply Category
      </button>
    </div>
  );
};

export default CategorySelect;
