import { currentUser } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { CategoryForm } from "~/app/_components/CategoryForm";

export default async function NewCategoryPage() {
  const user = await currentUser();
  if (!user?.id) redirect("/sign-in");

  return (
    <div className="container mx-auto p-4">
      <CategoryForm userId={user.id} />
    </div>
  );
}