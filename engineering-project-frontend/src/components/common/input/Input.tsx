"use client";

import React from "react";
import clsx from "clsx";

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  dark?: boolean;
}

const Input: React.FC<InputProps> = ({
  dark = false,
  className = "",
  ...props
}) => {
  return (
    <input
      {...props}
      className={clsx(
        "w-full px-4 py-2 rounded-md border border-gray-600 text-sm outline-none",
        dark
          ? "bg-[#1F1F1F] text-white placeholder-gray-400"
          : "bg-white text-black",
        "focus:ring-0 focus:outline-none",
        className
      )}
    />
  );
};

export default Input;
