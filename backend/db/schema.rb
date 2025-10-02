# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_01_01_000006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "color"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "import_jobs", force: :cascade do |t|
    t.string "status", default: "pending", null: false
    t.integer "total_rows", default: 0
    t.integer "processed_rows", default: 0
    t.integer "successful_rows", default: 0
    t.integer "failed_rows", default: 0
    t.jsonb "error_log", default: []
    t.string "filename"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_import_jobs_on_created_at"
    t.index ["status"], name: "index_import_jobs_on_status"
  end

  create_table "rules", force: :cascade do |t|
    t.string "name", null: false
    t.string "condition_type", null: false
    t.string "condition_value", null: false
    t.string "action_type", null: false
    t.string "action_value"
    t.bigint "category_id"
    t.boolean "active", default: true, null: false
    t.integer "priority", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "priority"], name: "idx_rules_active_priority", order: { priority: :desc }
    t.index ["active", "priority"], name: "index_rules_on_active_and_priority"
    t.index ["active"], name: "index_rules_on_active"
    t.index ["category_id"], name: "index_rules_on_category_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.date "transaction_date", null: false
    t.text "description"
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.bigint "category_id"
    t.boolean "reviewed", default: false, null: false
    t.boolean "flagged_as_anomaly", default: false, null: false
    t.string "anomaly_reason"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower(description)", name: "idx_transactions_description_lower"
    t.index ["amount"], name: "index_transactions_on_amount"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["created_at", "transaction_date"], name: "idx_transactions_created_at_date"
    t.index ["created_at"], name: "index_transactions_on_created_at"
    t.index ["flagged_as_anomaly"], name: "index_transactions_on_flagged_as_anomaly"
    t.index ["id"], name: "idx_flagged", where: "(flagged_as_anomaly = true)"
    t.index ["id"], name: "idx_needs_review", where: "((reviewed = false) AND ((flagged_as_anomaly = true) OR (category_id IS NULL)))"
    t.index ["id"], name: "idx_uncategorized", where: "(category_id IS NULL)"
    t.index ["metadata"], name: "index_transactions_on_metadata", using: :gin
    t.index ["reviewed", "category_id"], name: "idx_transactions_review_category"
    t.index ["reviewed", "flagged_as_anomaly"], name: "index_transactions_on_reviewed_and_flagged_as_anomaly"
    t.index ["reviewed"], name: "index_transactions_on_reviewed"
    t.index ["transaction_date", "amount"], name: "idx_transactions_date_amount"
    t.index ["transaction_date", "amount"], name: "index_transactions_on_transaction_date_and_amount"
    t.index ["transaction_date"], name: "index_transactions_on_transaction_date"
  end

  add_foreign_key "rules", "categories"
  add_foreign_key "transactions", "categories"
end
