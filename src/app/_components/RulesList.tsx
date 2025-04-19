import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { useRouter } from "next/navigation";
import { api } from "~/trpc/react";
import { ScrollArea } from "@/components/ui/scroll-area";
import { toast } from "sonner";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger } from "@/components/ui/alert-dialog";

interface RulesListProps {
  userId: string;
  maxHeight?: string;
}

export function RulesList({ userId, maxHeight = "calc(100vh - 200px)" }: RulesListProps) {
  const router = useRouter();
  const utils = api.useUtils();
  const { data: rules, isLoading } = api.rule.getCategorizationRules.useQuery({
    userId,
  });

  const deleteRuleMutation = api.rule.deleteCategorizationRule.useMutation({
    onSuccess: () => {
      toast.success("Rule deleted successfully");
      void utils.rule.getCategorizationRules.invalidate();
    },
    onError: (error) => {
      toast.error("Failed to delete rule: " + error.message);
    },
  });

  const handleDeleteRule = async (e: React.MouseEvent, ruleId: string) => {
    e.stopPropagation();
    if (!userId) {
      toast.error("User ID is required");
      return;
    }
    try {
      await deleteRuleMutation.mutateAsync({
        userId,
        ruleId,
      });
    } catch (error) {
      console.error("Failed to delete rule:", error);
      toast.error("Failed to delete rule");
    }
  };

  if (isLoading) {
    return (
      <Card className="p-6">
        <div className="text-center text-muted-foreground">Loading rules...</div>
      </Card>
    );
  }

  if (!rules?.length) {
    return (
      <Card className="p-6">
        <div className="text-center text-muted-foreground">
          No rules created yet. Add a rule to start automating your transaction categorization.
        </div>
      </Card>
    );
  }

  return (
    <ScrollArea className="w-full rounded-md" style={{ maxHeight }}>
      <div className="space-y-3 pr-4">
        {rules.map((rule) => (
          <Card
            key={rule.id}
            className="p-4 hover:bg-accent/50 cursor-pointer transition-colors"
            onClick={() => router.push(`/rules/${rule.id}`)}
          >
            <div className="flex items-center justify-between gap-4">
              <div className="min-w-0 flex-1">
                <h3 className="font-medium truncate">{rule.name}</h3>
                <p className="text-sm text-muted-foreground line-clamp-2">
                  {rule.conditionType === "description" && `If description ${rule.conditionSubtype} "${rule.conditionValue}"`}
                  {rule.conditionType === "amount" && `If amount ${rule.conditionSubtype} $${rule.conditionValue}`}
                  {rule.conditionType === "date" && `If date ${rule.conditionSubtype} ${rule.conditionValue}`}
                  {rule.conditionType === "ai" && `AI-based categorization: ${rule.aiPrompt}`}
                  {rule.category && `, categorize as "${rule.category.name}"`}
                </p>
              </div>
              <div className="flex gap-2 shrink-0">
                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={(e) => {
                    e.stopPropagation();
                    router.push(`/rules/${rule.id}`);
                  }}
                >
                  Edit
                </Button>
                <AlertDialog>
                  <AlertDialogTrigger asChild>
                    <Button
                      variant="destructive"
                      size="sm"
                      onClick={(e) => e.stopPropagation()}
                    >
                      Delete
                    </Button>
                  </AlertDialogTrigger>
                  <AlertDialogContent>
                    <AlertDialogHeader>
                      <AlertDialogTitle>Are you sure?</AlertDialogTitle>
                      <AlertDialogDescription>
                        This action cannot be undone. This will permanently delete the rule &quot;{rule.name}&quot;.
                      </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                      <AlertDialogCancel>Cancel</AlertDialogCancel>
                      <AlertDialogAction onClick={(e) => handleDeleteRule(e, rule.id)}>
                        Delete
                      </AlertDialogAction>
                    </AlertDialogFooter>
                  </AlertDialogContent>
                </AlertDialog>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </ScrollArea>
  );
} 