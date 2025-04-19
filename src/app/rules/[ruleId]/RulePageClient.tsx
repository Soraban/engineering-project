"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useUser } from "@clerk/nextjs";
import { RuleForm } from "~/app/_components/RuleForm";
import { api } from "~/trpc/react";
import { redirect, useRouter } from "next/navigation";
import { useEffect } from "react";

interface RulePageClientProps {
  ruleId: string;
}

export default function RulePageClient({ ruleId }: RulePageClientProps) {
  const { user } = useUser();
  const router = useRouter();

  if (!user?.id) {
    redirect("/sign-in");
  }

  const { data: rule, isLoading } = api.rule.getRuleById.useQuery(
    {
      userId: user.id,
      ruleId,
    },
    {
      retry: false,
    }
  );

  useEffect(() => {
    if (!isLoading && !rule) {
      router.push('/rules');
    }
  }, [isLoading, rule, router]);

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <Card>
          <CardHeader>
            <CardTitle>Loading rule...</CardTitle>
          </CardHeader>
        </Card>
      </div>
    );
  }

  if (!rule) {
    return null;
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <Card>
        <CardHeader>
          <CardTitle>Edit Rule</CardTitle>
        </CardHeader>
        <CardContent>
          <RuleForm userId={user.id} initialData={rule} />
        </CardContent>
      </Card>
    </div>
  );
} 