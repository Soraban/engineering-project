"use client";

import { api } from "~/trpc/react";
import { Button } from "~/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "~/components/ui/card";
import { Input } from "~/components/ui/input";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Textarea } from "@/components/ui/textarea";

const formSchema = z.object({
  name: z.string()
    .min(1, "Category name is required")
    .max(50, "Category name cannot exceed 50 characters")
    .refine(name => name.trim().length > 0, "Category name cannot be only whitespace"),
  description: z.string()
    .max(500, "Description cannot exceed 500 characters")
    .optional()
    .transform(val => val === "" ? undefined : val),
});

type FormValues = z.infer<typeof formSchema>;

interface CategoryFormProps {
  userId: string;
  categoryId?: string;
  initialData?: {
    name?: string;
    description?: string;
  };
}

export function CategoryForm({ userId, initialData, categoryId }: CategoryFormProps) {
  const router = useRouter();
  const utils = api.useUtils();

  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      name: initialData?.name ?? "",
      description: initialData?.description ?? "",
    },
  });

  const createCategory = api.category.create.useMutation({
    onSuccess: async () => {
      await utils.category.getAll.invalidate({ userId });
      toast.success("Category created successfully");
      router.push("/categories");
    },
    onError: (error) => {
      toast.error("Failed to create category: " + error.message);
    }
  });

  const updateCategory = api.category.update.useMutation({
    onSuccess: async () => {
      await utils.category.getAll.invalidate({ userId });
      toast.success("Category updated successfully");
      router.push("/categories");
    },
    onError: (error) => {
      toast.error("Failed to update category: " + error.message);
    }
  });

  const isPending = createCategory.isPending || updateCategory.isPending;

  function onSubmit(values: FormValues) {
    if (categoryId !== undefined) {
      updateCategory.mutate({
        userId,
        categoryId: categoryId,
        name: values.name.trim(),
        description: values.description,
      });
    } else {
      createCategory.mutate({
        name: values.name.trim(),
        description: values.description,
        userId,
      });
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{categoryId ? "Edit Category" : "New Category"}</CardTitle>
      </CardHeader>
      <CardContent>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Name</FormLabel>
                  <FormControl>
                    <Input placeholder="Enter category name" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Description (Optional)</FormLabel>
                  <FormControl>
                    <Textarea
                      placeholder="Enter category description"
                      rows={4}
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="flex justify-end space-x-4">
              <Button
                type="button"
                variant="outline"
                onClick={() => router.push("/categories")}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={isPending}
              >
                {isPending
                  ? "Saving..."
                  : categoryId
                  ? "Save Changes"
                  : "Create Category"}
              </Button>
            </div>
          </form>
        </Form>
      </CardContent>
    </Card>
  );
} 