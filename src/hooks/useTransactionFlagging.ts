import { useEffect, useRef, useState } from "react";
import { api } from "~/trpc/react";
import { useUser } from "@clerk/nextjs";

export function useTransactionFlagging() {
  const { user } = useUser();
  const hasProcessedRef = useRef(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const lastTransactionCountRef = useRef(0);
  const utils = api.useUtils();

  // Get all transactions to analyze
  const { data: transactions, isLoading: isLoadingTransactions, isFetching } = api.transaction.getAll.useQuery(
    { userId: user?.id ?? "" },
    { 
      enabled: !!user,
      staleTime: 3000, // Wait 3 seconds before refetching
      retry: false
    }
  );

  const flagTransaction = api.transaction.flag.useMutation({
    onSuccess: async () => {
      // Invalidate queries to refresh the UI
      await Promise.all([
        utils.transaction.getAll.invalidate({ userId: user?.id ?? "" }),
        utils.transaction.getNeedingReview.invalidate({ userId: user?.id ?? "" })
      ]);
      // Set processing to false after each flag is found
      setIsProcessing(false);
    },
    onError: (error) => {
      console.error("Error flagging transaction:", error);
      setIsProcessing(false);
    }
  });

  useEffect(() => {
    let isMounted = true;

    const processTransactions = async () => {
      // Skip if no transactions or still loading
      if (!user || !transactions || isLoadingTransactions || isFetching) {
        setIsProcessing(false);
        return;
      }

      // Skip if no transactions to process
      if (transactions.length === 0) {
        setIsProcessing(false);
        hasProcessedRef.current = true;
        return;
      }

      // Reset processing state if transaction count has changed
      const currentTransactionCount = transactions.length;
      if (currentTransactionCount !== lastTransactionCountRef.current) {
        hasProcessedRef.current = false;
        lastTransactionCountRef.current = currentTransactionCount;
      }

      // Skip if already processed
      if (hasProcessedRef.current) {
        setIsProcessing(false);
        return;
      }

      try {
        hasProcessedRef.current = true;
        setIsProcessing(true);

        // Function to calculate average amount
        const calculateAverage = (amounts: number[]) => {
          if (amounts.length === 0) return 0;
          const sum = amounts.reduce((acc, val) => acc + val, 0);
          return sum / amounts.length;
        };

        // Function to calculate standard deviation
        const calculateStdDev = (amounts: number[], mean: number) => {
          if (amounts.length === 0) return 0;
          const squareDiffs = amounts.map(value => Math.pow(value - mean, 2));
          const avgSquareDiff = calculateAverage(squareDiffs);
          return Math.sqrt(avgSquareDiff);
        };

        // Create a map to track duplicates
        const transactionMap = new Map();

        // Pre-calculate all amounts for better performance
        const transactionAmounts = transactions.map(t => parseFloat(t.amount.toString()));
        const avgAmount = calculateAverage(transactionAmounts);
        const stdDev = calculateStdDev(transactionAmounts, avgAmount);
        const upperThreshold = avgAmount + 2 * stdDev;
        const lowerThreshold = avgAmount - 2 * stdDev;

        // Process transactions in parallel
        const processPromises = transactions.map(async (transaction) => {
          if (!isMounted) return;

          // Skip if transaction has been previously approved
          if (transaction.wasApproved) {
            return;
          }

          const amount = parseFloat(transaction.amount.toString());
          const key = `${amount}-${transaction.date.toISOString()}-${transaction.description}`;

          try {
            // Check for duplicates
            if (transactionMap.has(key)) {
              await flagTransaction.mutateAsync({
                userId: user.id,
                transactionId: transaction.id,
                flag: "duplicate"
              });
            }
            transactionMap.set(key, transaction);

            // Check for unusual amount (outliers both high and low)
            if (amount > upperThreshold || amount < lowerThreshold) {
              await flagTransaction.mutateAsync({
                userId: user.id,
                transactionId: transaction.id,
                flag: "unusual_amount"
              });
            }

            // Check for incomplete data
            if (!transaction.description || !transaction.date) {
              await flagTransaction.mutateAsync({
                userId: user.id,
                transactionId: transaction.id,
                flag: "incomplete"
              });
            }

            // Check for uncategorized transactions
            if (!transaction.categories || transaction.categories.length === 0) {
              await flagTransaction.mutateAsync({
                userId: user.id,
                transactionId: transaction.id,
                flag: "uncategorized"
              });
            }
          } catch (error) {
            console.error("Error processing transaction:", transaction.id, error);
          }
        });

        // Wait for all transactions to be processed
        await Promise.all(processPromises);
      } catch (error) {
        console.error("Error in processTransactions:", error);
      } finally {
        if (isMounted) {
          setIsProcessing(false);
        }
      }
    };

    void processTransactions();

    return () => {
      isMounted = false;
    };
  }, [user, transactions, isLoadingTransactions, isFetching, flagTransaction, utils]);

  return { isProcessing };
} 