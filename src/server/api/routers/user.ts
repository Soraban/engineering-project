import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "~/server/api/trpc";
import { db } from "~/server/db";
import { users } from "~/server/db/schema";
import { eq } from "drizzle-orm";

export const userRouter = createTRPCRouter({
  // Get current user
  getCurrent: publicProcedure
    .input(z.object({ userId: z.string() }))
    .query(async ({ input }) => {
      return db.query.users.findFirst({
        where: eq(users.id, input.userId),
      });
    }),

  // Create or update user
  upsert: publicProcedure
    .input(
      z.object({
        id: z.string(),
        email: z.string().email(),
        name: z.string().optional(),
      }),
    )
    .mutation(async ({ input }) => {
      const existingUser = await db.query.users.findFirst({
        where: eq(users.id, input.id),
      });

      if (existingUser) {
        // Update user
        return db
          .update(users)
          .set({
            email: input.email,
            name: input.name,
          })
          .where(eq(users.id, input.id));
      }

      // Create user
      return db.insert(users).values({
        id: input.id,
        email: input.email,
        name: input.name,
      });
    }),

  // Delete user
  delete: publicProcedure
    .input(z.object({ userId: z.string() }))
    .mutation(async ({ input }) => {
      return db.delete(users).where(eq(users.id, input.userId));
    }),

  // Update user profile
  updateProfile: publicProcedure
    .input(
      z.object({
        userId: z.string(),
        name: z.string().optional(),
        email: z.string().email().optional(),
      }),
    )
    .mutation(async ({ input }) => {
      const { userId, ...updateData } = input;
      return db
        .update(users)
        .set(updateData)
        .where(eq(users.id, userId));
    }),
}); 