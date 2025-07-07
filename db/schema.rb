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

ActiveRecord::Schema[7.1].define(version: 2025_07_07_192523) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "account_balances", force: :cascade do |t|
    t.bigint "bank_connection_id", null: false
    t.decimal "current_balance", precision: 15, scale: 2
    t.decimal "available_balance", precision: 15, scale: 2
    t.decimal "ledger_balance", precision: 15, scale: 2
    t.string "currency", default: "NGN"
    t.datetime "balance_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_connection_id", "balance_date"], name: "index_account_balances_on_bank_connection_id_and_balance_date"
    t.index ["bank_connection_id"], name: "index_account_balances_on_bank_connection_id"
  end

  create_table "bank_connections", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "bank_code", null: false
    t.string "bank_name", null: false
    t.string "account_number", null: false
    t.string "account_name"
    t.string "account_type"
    t.text "encrypted_access_token"
    t.text "encrypted_refresh_token"
    t.datetime "token_expires_at"
    t.string "consent_id"
    t.string "status", default: "active"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consent_id"], name: "index_bank_connections_on_consent_id"
    t.index ["user_id", "bank_code", "account_number"], name: "idx_on_user_id_bank_code_account_number_d42a2d1f9e", unique: true
    t.index ["user_id"], name: "index_bank_connections_on_user_id"
  end

  create_table "credit_applications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "credit_score_id"
    t.decimal "requested_amount", precision: 15, scale: 2
    t.string "loan_purpose"
    t.integer "loan_term_months"
    t.decimal "proposed_interest_rate", precision: 5, scale: 4
    t.string "status", default: "pending"
    t.text "rejection_reason"
    t.json "terms_and_conditions"
    t.datetime "approved_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_score_id"], name: "index_credit_applications_on_credit_score_id"
    t.index ["status"], name: "index_credit_applications_on_status"
    t.index ["user_id", "status"], name: "index_credit_applications_on_user_id_and_status"
    t.index ["user_id"], name: "index_credit_applications_on_user_id"
  end

  create_table "credit_scores", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "score", null: false
    t.string "grade"
    t.decimal "default_probability", precision: 5, scale: 4
    t.json "score_breakdown"
    t.json "risk_factors"
    t.json "improvement_suggestions"
    t.string "model_version"
    t.datetime "calculated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["score"], name: "index_credit_scores_on_score"
    t.index ["user_id", "calculated_at"], name: "index_credit_scores_on_user_id_and_calculated_at"
    t.index ["user_id"], name: "index_credit_scores_on_user_id"
  end

  create_table "financial_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "average_monthly_income", precision: 15, scale: 2
    t.decimal "average_monthly_expenses", precision: 15, scale: 2
    t.decimal "savings_rate", precision: 5, scale: 4
    t.decimal "debt_to_income_ratio", precision: 5, scale: 4
    t.decimal "expense_volatility", precision: 5, scale: 4
    t.integer "transaction_frequency"
    t.json "spending_categories"
    t.json "income_sources"
    t.datetime "profile_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_financial_profiles_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "bank_connection_id", null: false
    t.string "transaction_id", null: false
    t.string "transaction_type"
    t.decimal "amount", precision: 15, scale: 2
    t.string "currency", default: "NGN"
    t.text "description"
    t.string "category"
    t.string "merchant_name"
    t.json "metadata"
    t.datetime "transaction_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_connection_id", "transaction_date"], name: "index_transactions_on_bank_connection_id_and_transaction_date"
    t.index ["bank_connection_id"], name: "index_transactions_on_bank_connection_id"
    t.index ["category"], name: "index_transactions_on_category"
    t.index ["transaction_id"], name: "index_transactions_on_transaction_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.string "bvn"
    t.string "nin"
    t.date "date_of_birth"
    t.string "employment_status"
    t.decimal "declared_income", precision: 15, scale: 2
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bvn"], name: "index_users_on_bvn", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "account_balances", "bank_connections"
  add_foreign_key "bank_connections", "users"
  add_foreign_key "credit_applications", "credit_scores"
  add_foreign_key "credit_applications", "users"
  add_foreign_key "credit_scores", "users"
  add_foreign_key "financial_profiles", "users"
  add_foreign_key "transactions", "bank_connections"
end
