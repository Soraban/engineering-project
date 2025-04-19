"use client";

import { useRouter } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Button } from "@/components/ui/button";
import { Trash2 } from "lucide-react";
import { api } from "~/trpc/react";
import { toast } from "sonner";
import type { InferSelectModel } from "drizzle-orm";
import type { categories } from "~/server/db/schema";

type Category = InferSelectModel<typeof categories>;

interface CategoryListProps {
  categories: Category[];
  maxHeight?: string;
  userId: string;
}

export function CategoryList({ categories, maxHeight = "calc(100vh - 200px)", userId }: CategoryListProps) {
  const router = useRouter();
  const utils = api.useUtils();
  const deleteCategory = api.category.delete.useMutation({
    onSuccess: async () => {
      await utils.category.getAll.invalidate({ userId });
      toast.success("Category deleted successfully");
    },
    onError: (error) => {
      toast.error(`Failed to delete category: ${error.message}`);
    }
  });

  const handleDelete = async (e: React.MouseEvent, categoryId: string) => {
    e.stopPropagation();
    try {
      await deleteCategory.mutateAsync({ userId, categoryId });
    } catch (error) {
      console.error("Error deleting category:", error);
    }
  };

  if (!categories || categories.length === 0) {
    return (
      <Card>
        <CardContent className="text-center py-8">
          <div className="text-muted-foreground">
            No categories available.
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <ScrollArea className="w-full rounded-md" style={{ maxHeight }}>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 pb-4">
        {categories.map((category) => (
          <Card
            key={category.id}
            className="cursor-pointer hover:bg-accent/50 transition-colors min-h-[4rem] sm:min-h-[6rem]"
            onClick={() => router.push(`/categories/${category.id}`)}
          >
            <CardHeader className="py-3 px-4">
              <div className="flex justify-between items-center">
                <CardTitle className="text-base sm:text-lg line-clamp-1">
                  {category.name}
                </CardTitle>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8"
                  onClick={(e) => handleDelete(e, category.id)}
                  disabled={deleteCategory.isPending}
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            </CardHeader>
            <CardContent className="pt-0 pb-3 px-4">
              <div className="text-xs sm:text-sm text-muted-foreground line-clamp-2 sm:line-clamp-3">
                {category.description ?? "No description provided"}
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </ScrollArea>
  );
} 