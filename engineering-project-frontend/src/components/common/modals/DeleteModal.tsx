import React, { useRef } from "react";

interface DeleteModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  text: string;
}

const DeleteModal: React.FC<DeleteModalProps> = ({
  onClose,
  onConfirm,
  text,
}) => {
  const modalRef = useRef<HTMLDivElement | null>(null);

  const handleOutsideClick = (e: React.MouseEvent) => {
    if (modalRef.current && !modalRef.current.contains(e.target as Node)) {
      onClose();
    }
  };

  return (
    <div
      className="fixed inset-0 bg-gray-900 bg-opacity-90 flex justify-center items-center z-50"
      onClick={handleOutsideClick}
    >
      <div
        ref={modalRef}
        className="bg-gray-800 p-6 rounded-md w-full md:w-1/3 mx-4"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-lg text-gray-200 font-semibold mb-8 ">
          Confirm Delete
        </h3>
        <p className="mb-8 text-gray-200 font-semibold">{text}</p>
        <div className="flex justify-between">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-gray-500 text-black rounded-md hover:bg-gray-400 font-semibold"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            className="px-4 py-2 bg-red-500 text-white rounded-md hover:bg-red-600 font-semibold"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  );
};

export default DeleteModal;
