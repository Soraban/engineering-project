import express from "express";
import {
  getTransactions,
  getTransactionById,
  createTransaction,
  deleteTransaction,
  deleteTransactions,
  createMultipleTransactions,
  bulkCategorizeTransactions,
} from "../controllers/transactionController";
import multer from "multer";

const router = express.Router();

const upload = multer({ storage: multer.memoryStorage() });

router.get("/", getTransactions);
router.get("/:id", getTransactionById);

router.post("/", createTransaction);
router.post("/bulk", upload.single("csvFile"), createMultipleTransactions);
router.post("/bulk-delete", deleteTransactions);
router.post("/bulk-categorize", bulkCategorizeTransactions);

router.delete("/:id", deleteTransaction);

export default router;
