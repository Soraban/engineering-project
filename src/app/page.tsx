"use client";

import { ArrowRight, FileText, ListChecks, Settings, Shield } from "lucide-react";
import { FeatureCard } from "@/components/feature-card";
import Link from "next/link";
import { useUser } from "@clerk/nextjs";
import { api } from "~/trpc/react";
import { useEffect } from "react";
import { useTransactionFlagging } from "~/hooks/useTransactionFlagging";

export default function Home() {
  const { user, isLoaded } = useUser();
  
  const { mutate: upsertUser } = api.user.upsert.useMutation();
  const { data: currentUser } = api.user.getCurrent.useQuery(
    { userId: user?.id ?? "" },
    { enabled: !!user }
  );

  // Use the transaction flagging hook
  useTransactionFlagging();

  useEffect(() => {
    if (!user || !isLoaded) return;

    // Only upsert if user doesn't exist or email has changed
    if (!currentUser || currentUser.email !== user.emailAddresses[0]?.emailAddress) {
      upsertUser({
        id: user.id,
        email: user.emailAddresses[0]?.emailAddress ?? "",
        name: `${user.firstName ?? ""} ${user.lastName ?? ""}`.trim() || undefined,
      });
    }
  }, [user, isLoaded, currentUser, upsertUser]);

  if (!isLoaded) {
    return <div>Loading...</div>;
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="text-center mb-12">
        <h1 className="text-4xl font-bold mb-4">Welcome to Soraban</h1>
        <p className="text-xl text-muted-foreground">
          Your intelligent bookkeeping system for efficient financial management
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <FeatureCard
          title="Transactions"
          description="Record and import transactions with ease. Support for CSV imports and manual entry."
          href="/transactions"
          icon={<FileText className="w-8 h-8" />}
        />
        <FeatureCard
          title="Categories"
          description="Organize your transactions with smart categorization and bulk actions."
          href="/categories"
          icon={<ListChecks className="w-8 h-8" />}
        />
        <FeatureCard
          title="Rules"
          description="Set up automatic categorization rules to save time on transaction management."
          href="/rules"
          icon={<Settings className="w-8 h-8" />}
        />
        <FeatureCard
          title="Reviews"
          description="Review flagged transactions and anomalies for better financial oversight."
          href="/reviews"
          icon={<Shield className="w-8 h-8" />}
        />
      </div>

      <div className="mt-12 text-center">
        <p className="text-muted-foreground mb-4">
          Ready to streamline your bookkeeping process?
        </p>
        <Link
          href="/transactions"
          className="inline-flex items-center gap-2 text-primary hover:underline"
        >
          Get Started <ArrowRight className="w-4 h-4" />
        </Link>
      </div>
    </div>
  );
}
