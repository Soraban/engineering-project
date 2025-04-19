"use client";

import { useState, useEffect } from "react";
import { api } from "~/trpc/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Textarea } from "@/components/ui/textarea";
import type { inferRouterOutputs } from "@trpc/server";
import type { AppRouter } from "~/server/api/root";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";

type RouterOutput = inferRouterOutputs<AppRouter>;
type Rule = RouterOutput["rule"]["getCategorizationRules"][number];

const conditionTypes = ["description", "amount", "date", "ai"] as const;
type ConditionType = (typeof conditionTypes)[number];

const conditionSubtypes = [
  "contains",
  "greater_than",
  "less_than",
  "equals",
  "not_equals",
  "before",
  "after",
  "between",
  "not_between",
  "greater_than_or_equal",
  "less_than_or_equal"
] as const;
type ConditionSubtype = (typeof conditionSubtypes)[number];

const formSchema = z.object({
  name: z.string().min(1, "Rule name is required"),
  conditionType: z.enum(conditionTypes, {
    required_error: "Please select a condition type",
  }),
  conditionSubtype: z.enum(conditionSubtypes, {
    required_error: "Please select a condition",
  }).optional(),
  conditionValue: z.string().optional(),
  optionalConditionValue: z.string().optional(),
  aiPrompt: z.string().optional(),
  categoryId: z.string().min(1, "Please select a category"),
}).superRefine((data, ctx) => {
  if (data.conditionType === "ai") {
    if (!data.aiPrompt) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "AI prompt is required for AI-based rules",
        path: ["aiPrompt"],
      });
    }
    return;
  }

  if (!data.conditionSubtype) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Condition is required",
      path: ["conditionSubtype"],
    });
    return;
  }

  if (!data.conditionValue) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Value is required",
      path: ["conditionValue"],
    });
    return;
  }

  if (["between", "not_between"].includes(data.conditionSubtype) && !data.optionalConditionValue) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "End value is required for between/not between conditions",
      path: ["optionalConditionValue"],
    });
  }
});

type FormValues = z.infer<typeof formSchema>;

interface RuleFormProps {
  userId: string;
  initialData?: Rule;
}

export function RuleForm({ userId, initialData }: RuleFormProps) {
  const router = useRouter();
  const utils = api.useUtils();

  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      name: initialData?.name ?? "",
      conditionType: initialData?.conditionType ?? "description",
      conditionSubtype: initialData?.conditionSubtype ?? undefined,
      conditionValue: initialData?.conditionValue ?? "",
      optionalConditionValue: initialData?.optionalConditionValue ?? "",
      aiPrompt: initialData?.aiPrompt ?? "",
      categoryId: initialData?.categoryId ?? "",
    },
  });

  const { data: categories } = api.category.getAll.useQuery({ userId });

  const createRule = api.rule.createCategorizationRule.useMutation({
    onSuccess: async () => {
      await utils.rule.getCategorizationRules.invalidate({ userId });
      toast.success("Rule created successfully");
      router.push("/rules");
    },
    onError: (error) => {
      toast.error(`Failed to create rule: ${error.message}`);
    }
  });

  const updateRule = api.rule.updateCategorizationRule.useMutation({
    onSuccess: async () => {
      await utils.rule.getCategorizationRules.invalidate({ userId });
      toast.success("Rule updated successfully");
      router.push("/rules");
    },
    onError: (error) => {
      toast.error(`Failed to update rule: ${error.message}`);
    }
  });

  const getSubtypeOptions = (type: ConditionType) => {
    switch (type) {
      case "description":
        return [
          { value: "contains", label: "Contains" },
          { value: "equals", label: "Equals" },
          { value: "not_equals", label: "Does not equal" },
        ] as const;
      case "amount":
        return [
          { value: "greater_than", label: "Greater than" },
          { value: "less_than", label: "Less than" },
          { value: "equals", label: "Equals" },
          { value: "greater_than_or_equal", label: "Greater than or equal" },
          { value: "less_than_or_equal", label: "Less than or equal" },
        ] as const;
      case "date":
        return [
          { value: "before", label: "Before" },
          { value: "after", label: "After" },
          { value: "between", label: "Between" },
          { value: "not_between", label: "Not between" },
        ] as const;
      case "ai":
        return [] as const;
    }
  };

  const conditionType = form.watch("conditionType");

  useEffect(() => {
    if (conditionType === "ai") {
      form.setValue("conditionSubtype", undefined);
      form.setValue("conditionValue", "");
      form.setValue("optionalConditionValue", "");
    } else {
      form.setValue("aiPrompt", "");
    }
  }, [conditionType, form]);

  function onSubmit(data: FormValues) {
    console.log("Form submitted with values:", data);
    const ruleData = {
      userId,
      ...data,
    };

    if (initialData?.id) {
      console.log("Updating rule with data:", ruleData);
      void updateRule.mutateAsync(
        { ...ruleData, ruleId: initialData.id },
      ).catch((error) => {
        console.error("Error updating rule:", error);
      });
    } else {
      console.log("Creating new rule with data:", ruleData);
      void createRule.mutateAsync(ruleData).catch((error) => {
        console.error("Error creating rule:", error);
      });
    }
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Rule Name</FormLabel>
              <FormControl>
                <Input placeholder="Enter rule name" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="conditionType"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Rule Type</FormLabel>
              <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="Select condition type" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="description">Description</SelectItem>
                  <SelectItem value="amount">Amount</SelectItem>
                  <SelectItem value="date">Date</SelectItem>
                  <SelectItem value="ai">AI-based</SelectItem>
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />

        {form.watch("conditionType") !== "ai" && (
          <FormField
            control={form.control}
            name="conditionSubtype"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Comparison</FormLabel>
                <Select onValueChange={field.onChange} defaultValue={field.value}>
                  <FormControl>
                    <SelectTrigger>
                      <SelectValue placeholder="Select condition" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {getSubtypeOptions(form.watch("conditionType")).map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )}
          />
        )}

        {conditionType === "ai" && (
          <FormField
            control={form.control}
            name="aiPrompt"
            render={({ field }) => (
              <FormItem>
                <FormLabel>AI Prompt</FormLabel>
                <FormControl>
                  <Textarea
                    {...field}
                    value={field.value ?? ""}
                    placeholder="Enter your AI prompt here. Example: 'If the transaction description contains food-related terms like restaurant, cafe, or grocery, categorize it as Food & Dining'"
                    className="min-h-[100px] resize-none"
                  />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        )}

        {conditionType !== "ai" && (
          <FormField
            control={form.control}
            name="conditionValue"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Value</FormLabel>
                <FormControl>
                  <Input
                    {...field}
                    placeholder={`Enter ${conditionType} value`}
                    type={conditionType === "amount" ? "number" : conditionType === "date" ? "date" : "text"}
                  />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        )}

        {(form.watch("conditionSubtype") === "between" || form.watch("conditionSubtype") === "not_between") && (
          <FormField
            control={form.control}
            name="optionalConditionValue"
            render={({ field }) => (
              <FormItem>
                <FormLabel>End Value</FormLabel>
                <FormControl>
                  <Input
                    type={form.watch("conditionType") === "date" ? "date" : "text"}
                    {...field}
                  />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        )}

        <FormField
          control={form.control}
          name="categoryId"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Category</FormLabel>
              <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="Select a category" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  {categories?.map((category) => (
                    <SelectItem key={category.id} value={category.id}>
                      {category.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="flex justify-end space-x-4">
          <Button
            type="button"
            variant="outline"
            onClick={() => router.push("/rules")}
          >
            Cancel
          </Button>
          <Button
            type="submit"
            disabled={createRule.isPending || updateRule.isPending}
          >
            {initialData
              ? updateRule.isPending
                ? "Updating..."
                : "Update Rule"
              : createRule.isPending
              ? "Creating..."
              : "Create Rule"
            }
          </Button>
        </div>
      </form>
    </Form>
  );
} 