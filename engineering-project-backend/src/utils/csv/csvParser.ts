import Papa from "papaparse";
import { Transaction } from "../../models/transactionModel";
import { partial_ratio } from "fuzzball";

const categoryRules = {
  Shopping: ["amazon", "ebay", "walmart"],
  Groceries: ["restaurant", "food"],
};

const flaggedRules = [
  {
    condition: (amount: number) => amount > 1000,
    reason: "High amount (> 1000)",
  },
];

export const parseCsvTransactions = (csvText: string) => {
  return new Promise<{
    validatedTransactions: Transaction[];
    anomalies: any[];
  }>((resolve, reject) => {
    const validatedTransactions: Transaction[] = [];
    const anomalies: any[] = [];

    Papa.parse<Transaction>(csvText, {
      header: true,
      skipEmptyLines: true,
      complete: (result) => {
        for (const tx of result.data) {
          const hasAllFields =
            tx.description &&
            typeof tx.amount === "string" &&
            !isNaN(new Date(tx.date || "").getTime());

          if (!hasAllFields) {
            anomalies.push({ ...tx, reason: "Missing or invalid fields" });
            continue;
          }

          const isDuplicate = validatedTransactions.some(
            (existingTx) =>
              existingTx.amount === parseFloat(tx.amount!.toString()) &&
              existingTx.description === tx.description &&
              existingTx.date === new Date(tx.date!).toISOString()
          );

          if (isDuplicate) {
            anomalies.push({
              ...tx,
              reason: "Duplicate transaction (same description, amount, date)",
            });
            continue;
          }

          let categoryAssigned = false;
          if (!tx.category) {
            for (const [category, keywords] of Object.entries(categoryRules)) {
              for (const keyword of keywords) {
                const match = partial_ratio(tx.description, keyword);
                if (match > 80) {
                  tx.category = category;
                  categoryAssigned = true;
                  break;
                }
              }
              if (categoryAssigned) break;
            }
          }

          if (!tx.category) {
            tx.category = "Uncategorized";
          }

          const amount = parseFloat(tx.amount!.toString());
          const isFlagged = flaggedRules.some((rule) => rule.condition(amount));

          validatedTransactions.push({
            description: tx.description!,
            amount,
            date: new Date(tx.date!).toISOString(),
            category: tx.category,
            isFlagged,
          });
        }
        resolve({ validatedTransactions, anomalies });
      },
      error: (error: any) => {
        reject(error);
      },
    });
  });
};
