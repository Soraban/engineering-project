ALTER TYPE "public"."rule_condition_type" ADD VALUE 'ai';--> statement-breakpoint
ALTER TABLE "public"."soraban-project_categorization_rule" ALTER COLUMN "condition_subtype" SET DATA TYPE text;--> statement-breakpoint
DROP TYPE "public"."rule_condition_subtype";--> statement-breakpoint
CREATE TYPE "public"."rule_condition_subtype" AS ENUM('contains', 'greater_than', 'less_than', 'equals', 'not_equals', 'before', 'after', 'between', 'not_between', 'greater_than_or_equal', 'less_than_or_equal');--> statement-breakpoint
ALTER TABLE "public"."soraban-project_categorization_rule" ALTER COLUMN "condition_subtype" SET DATA TYPE "public"."rule_condition_subtype" USING "condition_subtype"::"public"."rule_condition_subtype";