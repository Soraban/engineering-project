CREATE TYPE "public"."flag_type" AS ENUM('incomplete', 'duplicate', 'unusual_amount', 'uncategorized');--> statement-breakpoint
CREATE TYPE "public"."rule_condition_type" AS ENUM('description', 'date', 'amount');--> statement-breakpoint
CREATE TYPE "public"."rule_condition_subtype" AS ENUM('contains', 'greater_than', 'less_than', 'equals', 'not_equals', 'ai', 'before', 'after', 'between', 'not_between', 'greater_than_or_equal', 'less_than_or_equal');--> statement-breakpoint
CREATE TABLE "soraban-project_transaction_category" (
	"transaction_id" uuid NOT NULL,
	"category_id" uuid NOT NULL,
	"added_by" text NOT NULL,
	"rule_id" uuid,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
ALTER TABLE "soraban-project_anomaly_rule" DISABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "soraban-project_transaction_review" DISABLE ROW LEVEL SECURITY;--> statement-breakpoint
DROP TABLE "soraban-project_anomaly_rule" CASCADE;--> statement-breakpoint
DROP TABLE "soraban-project_transaction_review" CASCADE;--> statement-breakpoint
ALTER TABLE "soraban-project_transaction" DROP CONSTRAINT "soraban-project_transaction_category_id_soraban-project_category_id_fk";
--> statement-breakpoint
DROP INDEX "categorization_rule_user_id_idx";--> statement-breakpoint
DROP INDEX "categorization_rule_category_id_idx";--> statement-breakpoint
DROP INDEX "transaction_category_id_idx";--> statement-breakpoint
ALTER TABLE "soraban-project_categorization_rule" ALTER COLUMN "category_id" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "soraban-project_categorization_rule" ADD COLUMN "name" text NOT NULL;--> statement-breakpoint
ALTER TABLE "soraban-project_categorization_rule" ADD COLUMN "condition_type" "rule_condition_type" NOT NULL;--> statement-breakpoint
ALTER TABLE "soraban-project_categorization_rule" ADD COLUMN "condition_value" text NOT NULL;--> statement-breakpoint
ALTER TABLE "soraban-project_categorization_rule" ADD COLUMN "optional_condition_value" text;--> statement-breakpoint
ALTER TABLE "soraban-project_categorization_rule" ADD COLUMN "ai_prompt" text;--> statement-breakpoint
ALTER TABLE "soraban-project_categorization_rule" ADD COLUMN "condition_subtype" "rule_condition_subtype" NOT NULL;--> statement-breakpoint
ALTER TABLE "soraban-project_transaction" ADD COLUMN "flags" "flag_type"[] DEFAULT '{}';--> statement-breakpoint
ALTER TABLE "soraban-project_transaction_category" ADD CONSTRAINT "soraban-project_transaction_category_transaction_id_soraban-project_transaction_id_fk" FOREIGN KEY ("transaction_id") REFERENCES "public"."soraban-project_transaction"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "soraban-project_transaction_category" ADD CONSTRAINT "soraban-project_transaction_category_category_id_soraban-project_category_id_fk" FOREIGN KEY ("category_id") REFERENCES "public"."soraban-project_category"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "soraban-project_transaction_category" ADD CONSTRAINT "soraban-project_transaction_category_rule_id_soraban-project_categorization_rule_id_fk" FOREIGN KEY ("rule_id") REFERENCES "public"."soraban-project_categorization_rule"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "transaction_category_transaction_idx" ON "soraban-project_transaction_category" USING btree ("transaction_id");--> statement-breakpoint
CREATE INDEX "transaction_category_category_idx" ON "soraban-project_transaction_category" USING btree ("category_id");--> statement-breakpoint
CREATE INDEX "rule_user_id_idx" ON "soraban-project_categorization_rule" USING btree ("user_id");--> statement-breakpoint
ALTER TABLE "soraban-project_categorization_rule" DROP COLUMN "condition";--> statement-breakpoint
ALTER TABLE "soraban-project_categorization_rule" DROP COLUMN "priority";--> statement-breakpoint
ALTER TABLE "soraban-project_categorization_rule" DROP COLUMN "is_active";--> statement-breakpoint
ALTER TABLE "soraban-project_transaction" DROP COLUMN "category_id";--> statement-breakpoint
ALTER TABLE "soraban-project_transaction" DROP COLUMN "flag_reason";--> statement-breakpoint
ALTER TABLE "soraban-project_transaction" DROP COLUMN "metadata";--> statement-breakpoint
ALTER TABLE "soraban-project_transaction" DROP COLUMN "source";