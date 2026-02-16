export function formatCurrency(amount: string | number): string {
  const value = typeof amount === "string" ? Number(amount) : amount

  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
  }).format(value)
}
