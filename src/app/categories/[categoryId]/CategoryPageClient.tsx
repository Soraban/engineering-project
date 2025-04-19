"use client";

import { CategoryForm } from "~/app/_components/CategoryForm";
import { api } from "~/trpc/react";
import { useUser } from "@clerk/nextjs";
import { redirect, useRouter } from "next/navigation";

interface CategoryPageClientProps {
  categoryId: string;
}

export default function CategoryPageClient({ categoryId }: CategoryPageClientProps) {
  const { user } = useUser();
  const router = useRouter();

  if (!user?.id) {
    redirect("/sign-in");
  }

  // Check if this is a new category (UUID format check)
  const isNewCategory = categoryId.length !== 36;

  const { data: category, isLoading, error } = api.category.getCategoryById.useQuery(
    { userId: user.id, categoryId },
    { 
      enabled: !!user && !!categoryId && !isNewCategory,
      retry: false // Don't retry if the category doesn't exist
    }
  );

  // Handle error by redirecting
  if (error) {
    router.push('/categories');
    return null;
  }

  // Show loading state while fetching category data
  if (!isNewCategory && isLoading) {
    return (
      <div className="container mx-auto p-4">
        <div className="text-center">Loading category data...</div>
      </div>
    );
  }

  // If trying to edit a non-existent category, redirect
  if (!isNewCategory && !category && !isLoading) {
    router.push('/categories');
    return null;
  }

  return (
    <div className="container mx-auto p-4">
      <CategoryForm 
        userId={user.id} 
        categoryId={isNewCategory ? undefined : categoryId}
        initialData={category ? {
          name: category.name,
          description: category.description ?? undefined,
        } : undefined}
      />
    </div>
  );
}