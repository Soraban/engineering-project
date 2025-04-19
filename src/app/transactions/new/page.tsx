import { currentUser } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { TransactionForm } from "~/app/_components/TransactionForm";

export default async function TransactionPage({
  params,
}: {
  params: { id: string };
}) {
  const user = await currentUser();

  if (!user?.id) {
    redirect("/sign-in");
  }

  return (
    <div className="container mx-auto py-8">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold mb-8">Add New Transaction</h1>
        <TransactionForm userId={user.id} />
      </div>
    </div>
  );
} 