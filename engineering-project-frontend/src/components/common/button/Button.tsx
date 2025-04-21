import React from "react";

interface ButtonProps {
  label: string;
  className?: string;
  disabled?: boolean;
  onClick: () => void;
  Icon?: React.ComponentType<React.SVGProps<SVGSVGElement>>;
}

const Button: React.FC<ButtonProps> = ({
  label,
  onClick,
  disabled,
  className = "",
  Icon,
}) => {
  return (
    <button
      disabled={disabled}
      onClick={onClick}
      className={`flex justify-center items-center gap-2 bg-blue hover:opacity-[90%] h-[40] w-full w-full md:max-w-fit px-4 rounded-md font-bold text-white ${
        disabled ? "bg-gray-400 opacity-[80%]" : ""
      } ${className}`}
    >
      {label} {Icon && <Icon />}
    </button>
  );
};

export default Button;
