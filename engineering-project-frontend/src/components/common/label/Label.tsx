import React from "react";

interface LabelProps {
  text: string;
  textColor?: string;
}

const Label: React.FC<LabelProps> = ({ text, textColor = "primary" }) => {
  return <span className={`font-semibold text-${textColor}`}>{text}</span>;
};

export default Label;
