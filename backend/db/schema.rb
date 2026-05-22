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

ActiveRecord::Schema[7.2].define(version: 2026_05_20_005653) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "anomalies", force: :cascade do |t|
    t.bigint "transaction_id", null: false
    t.string "anomaly_type", limit: 100, null: false
    t.string "severity", limit: 20, default: "medium"
    t.jsonb "details", default: {}
    t.text "explanation"
    t.datetime "explanation_generated_at"
    t.boolean "resolved", default: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.index ["resolved"], name: "idx_anomalies_unresolved", where: "(resolved = false)"
    t.index ["transaction_id", "anomaly_type"], name: "idx_anomalies_transaction_type"
    t.index ["transaction_id"], name: "index_anomalies_on_transaction_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "rules", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", limit: 200, null: false
    t.jsonb "condition", null: false
    t.jsonb "action", null: false
    t.integer "priority", default: 0
    t.boolean "active", default: true
    t.boolean "continue_processing", default: false
    t.integer "match_count", default: 0
    t.datetime "last_matched_at"
    t.decimal "match_rate", precision: 5, scale: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "active", "priority"], name: "idx_rules_user_active_priority"
    t.index ["user_id"], name: "index_rules_on_user_id"
  end

  create_table "transaction_transitions", force: :cascade do |t|
    t.string "to_state", null: false
    t.jsonb "metadata", default: {}
    t.integer "sort_key", null: false
    t.bigint "transaction_id", null: false
    t.boolean "most_recent", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["transaction_id", "most_recent"], name: "idx_tt_transaction_most_recent", unique: true, where: "most_recent"
    t.index ["transaction_id", "sort_key"], name: "idx_tt_transaction_sort_key", unique: true
    t.index ["transaction_id"], name: "index_transaction_transitions_on_transaction_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "date", null: false
    t.text "description"
    t.text "description_normalized"
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.string "category", limit: 100
    t.string "status", limit: 50, default: "pending"
    t.string "source", limit: 20, default: "manual"
    t.jsonb "anomaly_flags", default: []
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "to_tsvector('english'::regconfig, COALESCE(description, ''::text))", name: "idx_transactions_description_gin", using: :gin
    t.index ["user_id", "amount"], name: "idx_transactions_amount"
    t.index ["user_id", "category"], name: "idx_transactions_category"
    t.index ["user_id", "date", "amount", "description_normalized"], name: "idx_transactions_duplicate_check"
    t.index ["user_id", "date"], name: "idx_transactions_user_date", order: { date: :desc }
    t.index ["user_id", "status"], name: "idx_transactions_status", where: "((status)::text <> 'reviewed'::text)"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "anomalies", "transactions", on_delete: :cascade
  add_foreign_key "rules", "users"
  add_foreign_key "transaction_transitions", "transactions"
  add_foreign_key "transactions", "users"
end
