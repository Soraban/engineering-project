import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "~/server/api/trpc";
import { db } from "~/server/db";
import { categories, transactionCategories } from "~/server/db/schema";
import { eq, and } from "drizzle-orm";

export const categoryRouter = createTRPCRouter({
  // Get all categories for a user
  getAll: publicProcedure
    .input(z.object({ userId: z.string() }))
    .query(async ({ input }) => {
      return db.query.categories.findMany({
        where: eq(categories.userId, input.userId),
        orderBy: (categories) => categories.name,
      });
    }),

  // Get a category by ID
  getCategoryById: publicProcedure
    .input(z.object({ 
      userId: z.string(),
      categoryId: z.string(),
    }))
    .query(async ({ input }) => {
      return db.query.categories.findFirst({
        where: and(
          eq(categories.id, input.categoryId),
          eq(categories.userId, input.userId),
        ),
      });
    }),

  // Create a new category
  create: publicProcedure
    .input(
      z.object({
        userId: z.string(),
        name: z.string(),
        description: z.string().optional(),
      }),
    )
    .mutation(async ({ input }) => {
      return db.insert(categories).values(input);
    }),

  // Update a category
  update: publicProcedure
    .input(
      z.object({
        userId: z.string(),
        categoryId: z.string(),
        name: z.string().optional(),
        description: z.string().optional(),
      }),
    )
    .mutation(async ({ input }) => {
      const { categoryId, userId, ...data } = input;
      return db
        .update(categories)
        .set(data)
        .where(
          and(
            eq(categories.id, categoryId),
            eq(categories.userId, userId),
          ),
        );
    }),

  // Delete a category
  delete: publicProcedure
    .input(
      z.object({
        userId: z.string(),
        categoryId: z.string(),
      }),
    )
    .mutation(async ({ input }) => {
      // First delete all transaction-category relationships
      await db
        .delete(transactionCategories)
        .where(
          and(
            eq(transactionCategories.categoryId, input.categoryId),
          ),
        );

      // Then delete the category
      return db
        .delete(categories)
        .where(
          and(
            eq(categories.id, input.categoryId),
            eq(categories.userId, input.userId),
          ),
        );
    }),

  // Get transactions for a category
  getTransactions: publicProcedure
    .input(
      z.object({
        userId: z.string(),
        categoryId: z.string(),
      }),
    )
    .query(async ({ input }) => {
      return db.query.transactionCategories.findMany({
        where: and(
          eq(transactionCategories.categoryId, input.categoryId),
        ),
        with: {
          transaction: true,
        },
      });
    }),
}); 