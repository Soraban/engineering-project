export const rules = [
  {
    condition: (tx: { description: string }) =>
      tx.description?.toLowerCase().includes("amazon"),
    apply: (tx: any) => (tx.category = "Shopping"),
  },
  {
    condition: (tx: { amount: number }) => tx.amount > 1000,
    apply: (tx: any) => (tx.category = "High Value"),
  },
];
