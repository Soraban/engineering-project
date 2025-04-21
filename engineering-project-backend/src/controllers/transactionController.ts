import { Request, Response } from "express";
import { PrismaClient } from "@prisma/client";
import { parseCsvTransactions } from "../utils/csv/csvParser";

const prisma = new PrismaClient();

export const getTransactions = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const transactions = await prisma.transaction.findMany();
    res.status(200).json(transactions);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: (error as Error).message });
  }
};

export const getTransactionById = async (
  req: Request,
  res: Response
): Promise<void> => {
  const { id } = req.params;

  try {
    const transaction = await prisma.transaction.findUnique({
      where: { id },
    });
    if (!transaction) {
      res.status(404).json({ error: "Transaction not found" });
      return;
    }
    res.status(200).json(transaction);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: (error as Error).message });
  }
};

export const createTransaction = async (
  req: Request,
  res: Response
): Promise<void> => {
  const {
    description,
    amount,
    date,
    category,
  }: { description: string; amount: number; date: string; category: string } =
    req.body;

  try {
    const newTransaction = await prisma.transaction.create({
      data: {
        description,
        amount: parseFloat(amount.toString()),
        date: new Date(date),
        category,
      },
    });
    res.status(201).json(newTransaction);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: (error as Error).message });
  }
};

export const createMultipleTransactions = async (
  req: Request,
  res: Response
) => {
  if (!req.file) {
    res.status(400).json({ error: "No file uploaded" });
    return;
  }

  try {
    const fileBuffer = req.file.buffer;
    const fileText = fileBuffer.toString("utf-8");

    const { validatedTransactions, anomalies } = await parseCsvTransactions(
      fileText
    );

    if (validatedTransactions.length === 0) {
      res.status(400).json({ error: "No valid transactions.", anomalies });
      return;
    }

    const created = await prisma.transaction.createMany({
      data: validatedTransactions,
      skipDuplicates: true,
    });

    res.status(201).json({
      message: "Transactions processed.",
      insertedCount: created.count,
      anomalies,
      transactions: validatedTransactions,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

export const deleteTransaction = async (
  req: Request,
  res: Response
): Promise<void> => {
  const { id } = req.params;

  try {
    await prisma.transaction.delete({
      where: { id },
    });
    res.status(200).json({ message: "Transaction deleted successfully." });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

export const deleteTransactions = async (
  req: Request,
  res: Response
): Promise<void> => {
  const { ids } = req.body;

  if (!Array.isArray(ids) || ids.length === 0) {
    res.status(400).json({ error: "No IDs provided." });
    return;
  }

  try {
    await prisma.transaction.deleteMany({ where: { id: { in: ids } } });

    res.status(200).json({ message: "Transactions deleted successfully." });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

export const bulkCategorizeTransactions = async (
  req: Request,
  res: Response
): Promise<void> => {
  const { category, transactionIds } = req.body;

  if (!category || !transactionIds || !Array.isArray(transactionIds)) {
    res
      .status(400)
      .json({ error: "Category and transactionIds are required." });
    return;
  }

  try {
    const updated = await prisma.transaction.updateMany({
      where: { id: { in: transactionIds } },
      data: { category },
    });

    res.status(200).json({
      message: "Transactions categorized successfully.",
      updatedCount: updated.count,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: (error as Error).message });
  }
};
