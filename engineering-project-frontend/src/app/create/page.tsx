import AddTransaction from "@/components/addTransaction/AddTransaction";
import Header from "@/components/common/header/Header";

export default function CreateTransactionPage() {
  return (
    <main className="h-screen flex flex-col gap-8 items-center bg-gray-700">
      <Header />
      <AddTransaction />
    </main>
  );
}
