"use client";

import { Button } from "@/components/ui/button";
import { Plus } from "lucide-react";
import { redirect, useRouter } from "next/navigation";
import { api } from "~/trpc/react";
import { useUser } from "@clerk/nextjs";
import { CategoryList } from "~/app/_components/CategoryList";

export default function CategoriesPage() {
  const router = useRouter();
  const { user } = useUser();
  const { data: categories, isLoading } = api.category.getAll.useQuery(
    { userId: user?.id ?? "" },
    { enabled: !!user }
  );

  const handleAddCategory = () => {
    router.push('/categories/new');
  };

  if (!user) {
    redirect("/sign-in");
  }

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold">Categories</h1>
          <Button onClick={handleAddCategory}>
            <Plus className="mr-2 h-4 w-4" />
            Add Category
          </Button>
        </div>
        <div className="text-center text-muted-foreground py-8">
          Loading categories...
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold">Categories</h1>
        <Button onClick={handleAddCategory}>
          <Plus className="mr-2 h-4 w-4" />
          Add Category
        </Button>
      </div>

      <CategoryList 
        categories={categories ?? []} 
        maxHeight="70vh" 
        userId={user.id}
      />
    </div>
  );
} 