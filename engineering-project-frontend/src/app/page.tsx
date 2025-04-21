import axios from "axios";
import Header from "@/components/common/header/Header";
import { API_URL } from "@/constants/url";
import TransactionApp from "@/components/transaction/Transaction";
import { Transaction } from "@/types/transaction";

const Home = async () => {
  const { data: transactions } = await axios.get<Transaction[]>(
    `${API_URL}/transactions`
  );

  return (
    <main className="h-screen flex flex-col gap-4 items-center bg-gray-700">
      <Header />
      <TransactionApp transactions={transactions || []} />
    </main>
  );
};

export default Home;
