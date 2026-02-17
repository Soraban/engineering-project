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

ActiveRecord::Schema[8.0].define(version: 2026_02_17_230409) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categorization_rules", force: :cascade do |t|
    t.string "pattern"
    t.string "category"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "kind", null: false
    t.decimal "min_amount", precision: 12, scale: 2
  end

  create_table "transactions", force: :cascade do |t|
    t.date "date", null: false
    t.text "description", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "flagged", default: false, null: false
    t.string "flag_reason"
    t.index ["category"], name: "index_transactions_on_category"
    t.index ["date", "amount", "description"], name: "idx_transactions_dedupe"
    t.index ["date", "created_at"], name: "index_transactions_on_date_and_created_at"
    t.index ["flagged"], name: "index_transactions_on_flagged"
  end
end
