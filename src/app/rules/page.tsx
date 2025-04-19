"use client";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Plus } from "lucide-react";
import { useRouter } from "next/navigation";
import { useUser } from "@clerk/nextjs";
import { RulesList } from "~/app/_components/RulesList";

export default function RulesPage() {
  const router = useRouter();
  const { user } = useUser();

  if (!user) return null;

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold">Categorization Rules</h1>
        <Button onClick={() => router.push("/rules/new")}>
          <Plus className="mr-2 h-4 w-4" />
          Add Rule
        </Button>
      </div>

      <div className="grid gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Active Rules</CardTitle>
          </CardHeader>
          <CardContent>
            <RulesList userId={user.id} />
          </CardContent>
        </Card>
      </div>
    </div>
  );
} 