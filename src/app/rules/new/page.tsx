"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useUser } from "@clerk/nextjs";
import { RuleForm } from "~/app/_components/RuleForm";
import { redirect } from "next/navigation";

export default function NewRulePage() {
  const { user } = useUser();

  if (!user) {
    redirect("/sign-in");
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <Card>
        <CardHeader>
          <CardTitle>Create New Rule</CardTitle>
        </CardHeader>
        <CardContent>
          <RuleForm userId={user.id} />
        </CardContent>
      </Card>
    </div>
  );
}
