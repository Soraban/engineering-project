import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import Link from "next/link";

interface FeatureCardProps {
  title: string;
  description: string;
  href: string;
  icon: React.ReactNode;
}

export function FeatureCard({ title, description, href, icon }: FeatureCardProps) {
  return (
    <Card className="hover:shadow-lg transition-shadow">
      <CardHeader>
        <div className="mb-4">{icon}</div>
        <CardTitle>{title}</CardTitle>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      <CardContent>
        <Button asChild>
          <Link href={href}>Get Started</Link>
        </Button>
      </CardContent>
    </Card>
  );
} 