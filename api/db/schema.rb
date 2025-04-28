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

ActiveRecord::Schema[8.0].define(version: 2025_04_27_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "rule_applications", force: :cascade do |t|
    t.bigint "transaction_id", null: false
    t.bigint "rule_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rule_id"], name: "index_rule_applications_on_rule_id"
    t.index ["transaction_id", "rule_id"], name: "index_rule_applications_on_transaction_id_and_rule_id", unique: true
    t.index ["transaction_id"], name: "index_rule_applications_on_transaction_id"
  end

  create_table "rules", force: :cascade do |t|
    t.string "condition_field", null: false
    t.string "condition_operator", null: false
    t.string "condition_value", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_rules_on_category_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.date "date", null: false
    t.string "description"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.bigint "category_id"
    t.boolean "flagged", default: false
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["amount"], name: "index_transactions_on_amount"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["date"], name: "index_transactions_on_date"
    t.index ["flagged"], name: "index_transactions_on_flagged"
  end

  add_foreign_key "rule_applications", "rules"
  add_foreign_key "rule_applications", "transactions"
  add_foreign_key "rules", "categories"
  add_foreign_key "transactions", "categories"
end
