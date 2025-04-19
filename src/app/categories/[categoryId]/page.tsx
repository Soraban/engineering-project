import CategoryPageClient from "./CategoryPageClient";
import { currentUser } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";

export default async function CategoryPage({
  params,
}: { 
  params: { categoryId: string } 
}) {
  const user = await currentUser();
  if (!user?.id) redirect("/sign-in");

  const categoryId = params.categoryId;
  
  return <CategoryPageClient categoryId={categoryId} />;
}