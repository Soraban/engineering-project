import express from "express";
import cors from "cors";
import transactionRoutes from "./routes/transactionRoutes";

const app = express();
app.use(cors());
app.use(express.json());

app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ limit: "50mb", extended: true }));

app.use("/transactions", transactionRoutes);

const PORT = process.env.PORT || 5001;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
