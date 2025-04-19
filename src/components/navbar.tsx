'use client';

import { usePathname } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { ModeToggle } from "@/components/mode-toggle";
import { UserButton } from "@clerk/nextjs";

export function Navbar() {
  const pathname = usePathname();
  
  // Don't show navbar on auth pages
  if (pathname?.startsWith('/sign-in') || pathname?.startsWith('/sign-up')) {
    return null;
  }

  return (
    <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container flex h-14 items-center">
        <Link href="/" className="mr-6 p-4 flex items-center space-x-2">
          <span className="font-bold text-xl">Soraban</span>
        </Link>
        <div className="ml-auto flex items-center space-x-4">
          <Button variant="ghost" asChild>
            <Link href="/dashboard">Dashboard</Link>
          </Button>
          <Button variant="ghost" asChild>
            <Link href="/transactions">Transactions</Link>
          </Button>
          <Button variant="ghost" asChild>
            <Link href="/categories">Categories</Link>
          </Button>
          <Button variant="ghost" asChild>
            <Link href="/rules">Rules</Link>
          </Button>
          <Button variant="ghost" asChild>
            <Link href="/reviews">Reviews</Link>
          </Button>
          <ModeToggle />
          <UserButton afterSignOutUrl="/sign-in" />
        </div>
      </div>
    </header>
  );
} 