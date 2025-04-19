"use client";

import { use } from "react";
import { ReviewPageClient } from "./ReviewPageClient";
import { useUser } from "@clerk/nextjs";
import { redirect } from "next/navigation";

export default function Page({
  params,
}: {
  params: Promise<{ transactionId: string }>;
}) {
  const { transactionId } = use(params);
  const { user } = useUser();

  if (!user) {
    redirect("/sign-in");
  }


  return <ReviewPageClient transactionId={transactionId} />;
}
