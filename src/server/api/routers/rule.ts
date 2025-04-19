import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "~/server/api/trpc";
import { db } from "~/server/db";
import { categorizationRules, transactions, transactionCategories, categories } from "~/server/db/schema";
import { eq, and } from "drizzle-orm";
import type { InferSelectModel } from "drizzle-orm";

type Transaction = InferSelectModel<typeof transactions>;
type Rule = InferSelectModel<typeof categorizationRules>;
type TransactionWithCategories = Transaction & {
  transactionCategories: { categoryId: string }[];
};

// Rule evaluation functions
async function evaluateRule(rule: typeof categorizationRules.$inferSelect, transaction: typeof transactions.$inferSelect): Promise<boolean> {
  switch (rule.conditionType) {
    case "description":
      if (rule.conditionSubtype === "contains") {
        return transaction.description?.toLowerCase().includes(rule.conditionValue.toLowerCase()) ?? false;
      }
      break;
    case "amount":
      const amount = parseFloat(transaction.amount.toString());
      const conditionValue = parseFloat(rule.conditionValue);
      switch (rule.conditionSubtype) {
        case "greater_than":
          return amount > conditionValue;
        case "less_than":
          return amount < conditionValue;
        case "equals":
          return amount === conditionValue;
        case "greater_than_or_equal":
          return amount >= conditionValue;
        case "less_than_or_equal":
          return amount <= conditionValue;
      }
      break;
    case "date":
      const date = transaction.date;
      const conditionDate = new Date(rule.conditionValue);
      const optionalDate = rule.optionalConditionValue ? new Date(rule.optionalConditionValue) : null;
      
      switch (rule.conditionSubtype) {
        case "before":
          return date < conditionDate;
        case "after":
          return date > conditionDate;
        case "between":
          return optionalDate ? date >= conditionDate && date <= optionalDate : false;
        case "not_between":
          return optionalDate ? date < conditionDate || date > optionalDate : false;
      }
      break;
    case "ai":
      if (!rule.categoryId) return false;
      
      const category = await db.query.categories.findFirst({
        where: eq(categories.id, rule.categoryId),
      });

      if (!category) return false;

      try {
        // Use absolute URL for the API endpoint
        const baseUrl = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
        const apiUrl = new URL("/api/llm-route", baseUrl);
        
        
        const response = await fetch(apiUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            // Add custom header to identify internal request
            "X-Internal-Request": "true"
          },
          body: JSON.stringify({
            transaction_date: transaction.date.toISOString(),
            transaction_description: transaction.description ?? "",
            transaction_amount: transaction.amount.toString(),
            category: {
              name: category.name,
              description: category.description ?? undefined,
            },
            ai_prompt: rule.aiPrompt ?? undefined,
          }),
        });

        if (!response.ok) {
          const errorText = await response.text();
          console.error("API Error Response:", errorText);
          throw new Error(`AI evaluation failed: ${response.statusText} - ${errorText}`);
        }

        const result = (await response.json()) as { decision: "apply" | "do not apply" };
        console.log("API Response:", result);
        return result.decision === "apply";
      } catch (error) {
        console.error("AI evaluation failed:", error);
        return false;
      }
  }
  return false;
}

export const ruleRouter = createTRPCRouter({
  // Categorization Rules
  getCategorizationRules: publicProcedure
    .input(z.object({ userId: z.string() }))
    .query(async ({ input }) => {
      return db.query.categorizationRules.findMany({
        where: eq(categorizationRules.userId, input.userId),
        with: {
          category: true,
        },
      });
    }),

  createCategorizationRule: publicProcedure
    .input(
      z.object({
        userId: z.string(),
        name: z.string(),
        conditionType: z.enum(["description", "amount", "date", "ai"]),
        conditionSubtype: z.enum([
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
        ]).optional(),
        conditionValue: z.string().optional(),
        optionalConditionValue: z.string().optional(),
        aiPrompt: z.string().optional(),
        categoryId: z.string(),
      }),
    )
    .mutation(async ({ input }) => {
      const ruleData = {
        ...input,
        conditionValue: input.conditionValue ?? "",
        conditionSubtype: input.conditionSubtype ?? "contains",
      };
      return db.insert(categorizationRules).values(ruleData);
    }),

  updateCategorizationRule: publicProcedure
    .input(
      z.object({
        userId: z.string(),
        ruleId: z.string(),
        name: z.string().optional(),
        conditionType: z.enum(["description", "amount", "date", "ai"]).optional(),
        conditionSubtype: z.enum([
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
        ]).optional(),
        conditionValue: z.string().optional(),
        optionalConditionValue: z.string().optional(),
        aiPrompt: z.string().optional(),
        categoryId: z.string(),
      }),
    )
    .mutation(async ({ input }) => {
      const { ruleId, userId, ...data } = input;
      return db
        .update(categorizationRules)
        .set(data)
        .where(
          and(
            eq(categorizationRules.id, ruleId),
            eq(categorizationRules.userId, userId),
          ),
        );
    }),

  // Delete a categorization rule
  deleteCategorizationRule: publicProcedure
    .input(
      z.object({
        userId: z.string(),
        ruleId: z.string(),
      }),
    )
    .mutation(async ({ input }) => {
      // First delete all transaction categories associated with this rule
      await db
        .delete(transactionCategories)
        .where(eq(transactionCategories.ruleId, input.ruleId));

      // Then delete the rule
      return db
        .delete(categorizationRules)
        .where(
          and(
            eq(categorizationRules.id, input.ruleId),
            eq(categorizationRules.userId, input.userId),
          ),
        );
    }),

  // Apply rules to transactions
  applyRules: publicProcedure
    .input(z.object({ userId: z.string() }))
    .mutation(async ({ input }) => {
      // Get all categorization rules
      const rules = await db.query.categorizationRules.findMany({
        where: eq(categorizationRules.userId, input.userId),
      });

      // Get all transactions with their categories
      const userTransactions = await db.query.transactions.findMany({
        where: eq(transactions.userId, input.userId),
        with: {
          transactionCategories: {
            columns: {
              categoryId: true,
            },
          },
        },
      }) as TransactionWithCategories[];

      // Apply rules to transactions
      for (const transaction of userTransactions) {
        // Get existing category IDs for this transaction
        const existingCategoryIds = new Set(
          transaction.transactionCategories.map((tc: { categoryId: string }) => tc.categoryId)
        );

        for (const rule of rules) {
          // Skip if the category is already applied
          if (rule.categoryId && existingCategoryIds.has(rule.categoryId)) {
            continue;
          }

          // Skip AI rules if the category is already applied
          if (rule.conditionType === "ai" && rule.categoryId && existingCategoryIds.has(rule.categoryId)) {
            continue;
          }

          const matches = await evaluateRule(rule, transaction);
          // Only add the category if it matches and hasn't been added yet
          if (matches && rule.categoryId && !existingCategoryIds.has(rule.categoryId)) {
            await db.insert(transactionCategories).values({
              transactionId: transaction.id,
              categoryId: rule.categoryId,
              addedBy: "rule",
              ruleId: rule.id,
            });
            // Add to set of existing categories to prevent duplicates in subsequent rules
            existingCategoryIds.add(rule.categoryId);
          }
        }
      }
    }),

  // Get a single rule by ID
  getRuleById: publicProcedure
    .input(z.object({
      userId: z.string(),
      ruleId: z.string(),
    }))
    .query(async ({ input }) => {
      const rule = await db.query.categorizationRules.findFirst({
        where: and(
          eq(categorizationRules.id, input.ruleId),
          eq(categorizationRules.userId, input.userId),
        ),
        with: {
          category: true,
        },
      });

      if (!rule) {
        return null;
      }

      return {
        ...rule,
        category: rule.category ?? null,
      };
    }),
}); 