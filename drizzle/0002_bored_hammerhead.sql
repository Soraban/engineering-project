CREATE TABLE "soraban-project_post" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"title" text NOT NULL,
	"content" text NOT NULL,
	"category_id" uuid,
	"is_published" boolean DEFAULT false NOT NULL,
	"published_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	"updated_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "soraban-project_post" ADD CONSTRAINT "soraban-project_post_user_id_soraban-project_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."soraban-project_user"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "soraban-project_post" ADD CONSTRAINT "soraban-project_post_category_id_soraban-project_category_id_fk" FOREIGN KEY ("category_id") REFERENCES "public"."soraban-project_category"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "post_user_id_idx" ON "soraban-project_post" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "post_category_id_idx" ON "soraban-project_post" USING btree ("category_id");--> statement-breakpoint
CREATE INDEX "post_is_published_idx" ON "soraban-project_post" USING btree ("is_published");