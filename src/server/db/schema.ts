import { sql } from "drizzle-orm";
import type { InferSelectModel } from "drizzle-orm";
import type { PgTableFn } from "drizzle-orm/pg-core";
import {
  index,
  pgTableCreator,
  text,
  timestamp,
  uuid,
  decimal,
  boolean,
  jsonb,
  pgEnum,
} from "drizzle-orm/pg-core";
import { relations } from "drizzle-orm";

export const createTable = pgTableCreator((name) => `soraban-project_${name}`);

// Users table (existing)
export const users = createTable(
  "user",
  (d) => ({
    id: text("id").primaryKey(),
    email: text("email").notNull().unique(),
    name: text("name"),
    createdAt: timestamp("created_at", { withTimezone: true })
      .default(sql`CURRENT_TIMESTAMP`)
      .notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).$onUpdate(() => new Date()),
  }),
  (t) => [index("user_email_idx").on(t.email)],
);

// Create an enum for rule types
export const flagsEnum = pgEnum('flag_type', ['incomplete', 'duplicate', 'unusual_amount',"uncategorized",]);
export const ruleConditionEnum = pgEnum('rule_condition_type', ['description', 'date', 'amount',"ai"]);
export const ruleConditionSubtypeEnum = pgEnum('rule_condition_subtype', ['contains', 'greater_than', 'less_than', 'equals',"not_equals","before","after","between","not_between","greater_than_or_equal","less_than_or_equal"]);

// Rules table
export const categorizationRules = createTable(
  "categorization_rule",
  (d) => ({
    id: uuid("id").primaryKey().defaultRandom(),
    userId: text("user_id").references(() => users.id).notNull(),
    name: text("name").notNull(),
    conditionType: ruleConditionEnum("condition_type").notNull(),
    conditionValue: text("condition_value").notNull(), // The value to compare against (e.g., "Amazon" or "1000")
    optionalConditionValue: text("optional_condition_value"), // The value to compare against (e.g., "Amazon" or "1000")
    aiPrompt: text("ai_prompt"), // The prompt to use for the AI
    categoryId: uuid("category_id").references(() => categories.id), // The category to assign to the transaction
    conditionSubtype: ruleConditionSubtypeEnum("condition_subtype").notNull(), // The field to check (e.g., "description" or "amount")
    createdAt: timestamp("created_at", { withTimezone: true })
      .default(sql`CURRENT_TIMESTAMP`)
      .notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).$onUpdate(() => new Date()),
  }),
  (t) => [
    index("rule_user_id_idx").on(t.userId),
  ],
);

// Categories table (modified)
export const categories = createTable(
  "category",
  (d) => ({
    id: uuid("id").primaryKey().defaultRandom(),
    name: text("name").notNull(),
    description: text("description"),
    userId: text("user_id").references(() => users.id).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .default(sql`CURRENT_TIMESTAMP`)
      .notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).$onUpdate(() => new Date()),
  }),
  (t) => [
    index("category_user_id_idx").on(t.userId),
    index("category_name_idx").on(t.name),
  ],
);

// Transactions table (modified)
export const transactions = createTable(
  "transaction",
  (d) => ({
    id: uuid("id").primaryKey().defaultRandom(),
    userId: text("user_id").references(() => users.id).notNull(),
    amount: decimal("amount", { precision: 19, scale: 4 }).notNull(),
    description: text("description"),
    date: timestamp("date", { withTimezone: true }).notNull(),
    isFlagged: boolean("is_flagged").default(false).notNull(),
    flags: flagsEnum("flags").array().default([]),
    createdAt: timestamp("created_at", { withTimezone: true })
      .default(sql`CURRENT_TIMESTAMP`)
      .notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).$onUpdate(() => new Date()),
    wasApproved: boolean("was_approved").notNull().default(false),
  }),
  (t) => [
    index("transaction_user_id_idx").on(t.userId),
    index("transaction_date_idx").on(t.date),
    index("transaction_is_flagged_idx").on(t.isFlagged),
  ],
);

// Transaction-Category many-to-many relationship table
export const transactionCategories = createTable(
  "transaction_category",
  (d) => ({
    id: uuid("id").primaryKey().defaultRandom(),
    transactionId: uuid("transaction_id")
      .references(() => transactions.id)
      .notNull(),
    categoryId: uuid("category_id")
      .references(() => categories.id)
      .notNull(),
    addedBy: text("added_by").notNull(), // 'user' or 'rule'
    ruleId: uuid("rule_id").references(() => categorizationRules.id), // Which rule added this category (if by rule)
    createdAt: timestamp("created_at", { withTimezone: true })
      .default(sql`CURRENT_TIMESTAMP`)
      .notNull(),
  }),
  (t) => [
    index("transaction_category_transaction_idx").on(t.transactionId),
    index("transaction_category_category_idx").on(t.categoryId),
  ],
);

// Define relations
export const transactionsRelations = relations(transactions, ({ many }) => ({
  transactionCategories: many(transactionCategories),
}));

export const categoriesRelations = relations(categories, ({ many }) => ({
  transactionCategories: many(transactionCategories),
  rules: many(categorizationRules),
}));

export const categorizationRulesRelations = relations(categorizationRules, ({ one }) => ({
  category: one(categories, {
    fields: [categorizationRules.categoryId],
    references: [categories.id],
  }),
}));

export const transactionCategoriesRelations = relations(transactionCategories, ({ one }) => ({
  transaction: one(transactions, {
    fields: [transactionCategories.transactionId],
    references: [transactions.id],
  }),
  category: one(categories, {
    fields: [transactionCategories.categoryId],
    references: [categories.id],
  }),
}));