CREATE TABLE "soraban-project_anomaly_rule" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"condition" jsonb NOT NULL,
	"severity" text NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "soraban-project_category" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"description" text,
	"user_id" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "soraban-project_categorization_rule" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"category_id" uuid NOT NULL,
	"condition" jsonb NOT NULL,
	"priority" integer DEFAULT 0 NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "soraban-project_transaction_review" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"transaction_id" uuid NOT NULL,
	"user_id" text NOT NULL,
	"status" text NOT NULL,
	"notes" text,
	"reviewed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "soraban-project_transaction" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"amount" numeric(19, 4) NOT NULL,
	"description" text,
	"date" timestamp with time zone NOT NULL,
	"category_id" uuid,
	"is_flagged" boolean DEFAULT false NOT NULL,
	"flag_reason" text,
	"metadata" jsonb,
	"source" text DEFAULT 'manual' NOT NULL,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "soraban-project_user" (
	"id" text PRIMARY KEY NOT NULL,
	"email" text NOT NULL,
	"name" text,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone,
	CONSTRAINT "soraban-project_user_email_unique" UNIQUE("email")
);
--> statement-breakpoint
ALTER TABLE "soraban-project_anomaly_rule" ADD CONSTRAINT "soraban-project_anomaly_rule_user_id_soraban-project_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."soraban-project_user"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "soraban-project_category" ADD CONSTRAINT "soraban-project_category_user_id_soraban-project_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."soraban-project_user"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "soraban-project_categorization_rule" ADD CONSTRAINT "soraban-project_categorization_rule_user_id_soraban-project_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."soraban-project_user"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "soraban-project_categorization_rule" ADD CONSTRAINT "soraban-project_categorization_rule_category_id_soraban-project_category_id_fk" FOREIGN KEY ("category_id") REFERENCES "public"."soraban-project_category"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "soraban-project_transaction_review" ADD CONSTRAINT "soraban-project_transaction_review_transaction_id_soraban-project_transaction_id_fk" FOREIGN KEY ("transaction_id") REFERENCES "public"."soraban-project_transaction"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "soraban-project_transaction_review" ADD CONSTRAINT "soraban-project_transaction_review_user_id_soraban-project_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."soraban-project_user"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "soraban-project_transaction" ADD CONSTRAINT "soraban-project_transaction_user_id_soraban-project_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."soraban-project_user"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "soraban-project_transaction" ADD CONSTRAINT "soraban-project_transaction_category_id_soraban-project_category_id_fk" FOREIGN KEY ("category_id") REFERENCES "public"."soraban-project_category"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "anomaly_rule_user_id_idx" ON "soraban-project_anomaly_rule" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "category_user_id_idx" ON "soraban-project_category" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "category_name_idx" ON "soraban-project_category" USING btree ("name");--> statement-breakpoint
CREATE INDEX "categorization_rule_user_id_idx" ON "soraban-project_categorization_rule" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "categorization_rule_category_id_idx" ON "soraban-project_categorization_rule" USING btree ("category_id");--> statement-breakpoint
CREATE INDEX "transaction_review_transaction_id_idx" ON "soraban-project_transaction_review" USING btree ("transaction_id");--> statement-breakpoint
CREATE INDEX "transaction_review_user_id_idx" ON "soraban-project_transaction_review" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "transaction_review_status_idx" ON "soraban-project_transaction_review" USING btree ("status");--> statement-breakpoint
CREATE INDEX "transaction_user_id_idx" ON "soraban-project_transaction" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "transaction_date_idx" ON "soraban-project_transaction" USING btree ("date");--> statement-breakpoint
CREATE INDEX "transaction_category_id_idx" ON "soraban-project_transaction" USING btree ("category_id");--> statement-breakpoint
CREATE INDEX "transaction_is_flagged_idx" ON "soraban-project_transaction" USING btree ("is_flagged");--> statement-breakpoint
CREATE INDEX "user_email_idx" ON "soraban-project_user" USING btree ("email");