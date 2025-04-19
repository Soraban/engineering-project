import { useState } from "react";
import { api } from "~/trpc/react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

export function CategoryManager({ userId }: { userId: string }) {
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");

  const { data: categories, isLoading } = api.category.getAll.useQuery({ userId });
  const createCategory = api.category.create.useMutation({
    onSuccess: () => {
      setName("");
      setDescription("");
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name) return;

    createCategory.mutate({
      userId,
      name,
      description: description || undefined,
    });
  };

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Add New Category</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="name">Category Name</Label>
              <Input
                id="name"
                value={name}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setName(e.target.value)}
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                value={description}
                onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setDescription(e.target.value)}
                rows={3}
              />
            </div>

            <Button
              type="submit"
              disabled={createCategory.isPending}
              className="w-full"
            >
              {createCategory.isPending ? "Adding..." : "Add Category"}
            </Button>
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Existing Categories</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div>Loading...</div>
          ) : (
            <div className="space-y-2">
              {categories?.map((category) => (
                <Card key={category.id}>
                  <CardContent className="p-4">
                    <div className="flex justify-between">
                      <div>
                        <p className="font-semibold">{category.name}</p>
                        {category.description && (
                          <p className="text-sm text-muted-foreground">
                            {category.description}
                          </p>
                        )}
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
} 