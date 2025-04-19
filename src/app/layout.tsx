import "~/styles/globals.css";

import { type Metadata } from "next";
import { Geist } from "next/font/google";
import { ClerkProvider } from "@clerk/nextjs";

import { ThemeProvider } from "@/components/theme-provider";
import { TRPCReactProvider } from "~/trpc/react";
import { Toaster } from "@/components/ui/sonner";
import { Navbar } from "@/components/navbar";

export const metadata: Metadata = {
  title: "Soraban Bookkeeping System",
  description: "A scalable bookkeeping system with automated categorization",
  icons: [{ rel: "icon", url: "/favicon.ico" }],
};

const geist = Geist({
  subsets: ["latin"],
  variable: "--font-geist-sans",
});

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${geist.variable}`} suppressHydrationWarning>
      <body className="bg-background min-h-screen font-sans antialiased">
        <ClerkProvider>
          <ThemeProvider
            attribute="class"
            defaultTheme="system"
            enableSystem
            disableTransitionOnChange
          >
            <TRPCReactProvider>
              <div className="relative flex min-h-screen flex-col">
                <Navbar />
                <main className="container mx-auto flex-1 px-4 py-8">
                  {children}
                </main>
              </div>
            </TRPCReactProvider>
            <Toaster />
          </ThemeProvider>
        </ClerkProvider>
      </body>
    </html>
  );
}
