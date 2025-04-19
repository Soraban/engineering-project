-- Migration 0001: Create tables for Users, Categories, Transactions, Categorization Rules, Anomaly Rules, and Transaction Reviews

-- Drop indexes if they already exist (to avoid conflicts)


-- Users table
CREATE TABLE "soraban-project_user" (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  name TEXT,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Index on Users (email)
CREATE INDEX user_email_idx ON "soraban-project_user"(email);

-- Categories table
CREATE TABLE "soraban-project_category" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  user_id TEXT NOT NULL REFERENCES "soraban-project_user"(id),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Indexes on Categories (user_id, name)
CREATE INDEX category_user_id_idx ON "soraban-project_category"(user_id);
CREATE INDEX category_name_idx ON "soraban-project_category"(name);

-- Transactions table
CREATE TABLE "soraban-project_transaction" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES "soraban-project_user"(id),
  amount NUMERIC(19, 4) NOT NULL,
  description TEXT,
  date TIMESTAMPTZ NOT NULL,
  category_id UUID REFERENCES "soraban-project_category"(id),
  is_flagged BOOLEAN DEFAULT FALSE NOT NULL,
  flag_reason TEXT,
  metadata JSONB,
  source TEXT DEFAULT 'manual' NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Indexes on Transactions (user_id, date, category_id, is_flagged)
CREATE INDEX transaction_user_id_idx ON "soraban-project_transaction"(user_id);
CREATE INDEX transaction_date_idx ON "soraban-project_transaction"(date);
CREATE INDEX transaction_category_id_idx ON "soraban-project_transaction"(category_id);
CREATE INDEX transaction_is_flagged_idx ON "soraban-project_transaction"(is_flagged);

-- Categorization Rules table
CREATE TABLE "soraban-project_categorization_rule" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES "soraban-project_user"(id),
  category_id UUID NOT NULL REFERENCES "soraban-project_category"(id),
  condition JSONB NOT NULL,
  priority INTEGER DEFAULT 0 NOT NULL,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Indexes on Categorization Rules (user_id, category_id)
CREATE INDEX categorization_rule_user_id_idx ON "soraban-project_categorization_rule"(user_id);
CREATE INDEX categorization_rule_category_id_idx ON "soraban-project_categorization_rule"(category_id);

-- Anomaly Rules table
CREATE TABLE "soraban-project_anomaly_rule" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES "soraban-project_user"(id),
  name TEXT NOT NULL,
  description TEXT,
  condition JSONB NOT NULL,
  severity TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Index on Anomaly Rules (user_id)
CREATE INDEX anomaly_rule_user_id_idx ON "soraban-project_anomaly_rule"(user_id);

-- Transaction Reviews table
CREATE TABLE "soraban-project_transaction_review" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID NOT NULL REFERENCES "soraban-project_transaction"(id),
  user_id TEXT NOT NULL REFERENCES "soraban-project_user"(id),
  status TEXT NOT NULL,
  notes TEXT,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Indexes on Transaction Reviews (transaction_id, user_id, status)
CREATE INDEX transaction_review_transaction_id_idx ON "soraban-project_transaction_review"(transaction_id);
CREATE INDEX transaction_review_user_id_idx ON "soraban-project_transaction_review"(user_id);
CREATE INDEX transaction_review_status_idx ON "soraban-project_transaction_review"(status);
