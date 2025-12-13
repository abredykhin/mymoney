-- Initial schema migration from legacy database
-- This migration converts the legacy schema to work with Supabase Auth

-- Create timestamp trigger function
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- PROFILES (formerly users_table)
-- This table stores user profile data and is linked to auth.users
-- Note: Supabase Auth manages authentication in auth.users table
CREATE TABLE profiles_table
(
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE NOT NULL,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

CREATE TRIGGER profiles_updated_at_timestamp
BEFORE UPDATE ON profiles_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW profiles
AS
  SELECT
    id,
    username,
    created_at,
    updated_at
  FROM
    profiles_table;

-- Trigger to automatically create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles_table (id, username)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- INSTITUTIONS
CREATE TABLE institutions_table
(
  id SERIAL PRIMARY KEY,
  institution_id text UNIQUE NOT NULL,
  name text NOT NULL,
  primary_color text,
  url text,
  logo text,
  updated_at timestamptz default now()
);

CREATE TRIGGER institutions_updated_at_timestamp
BEFORE UPDATE ON institutions_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW institutions
AS
  SELECT
    id,
    institution_id,
    name,
    primary_color,
    url,
    logo,
    updated_at
  FROM
    institutions_table;

-- ITEMS
-- This table stores Plaid items associated with each user
CREATE TABLE items_table
(
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES profiles_table(id) ON DELETE CASCADE,
  bank_name text,
  plaid_access_token text UNIQUE NOT NULL,
  plaid_item_id text UNIQUE NOT NULL,
  plaid_institution_id text NOT NULL,
  status text NOT NULL,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  transactions_cursor text,
  is_active boolean NOT NULL DEFAULT TRUE
);

CREATE TRIGGER items_updated_at_timestamp
BEFORE UPDATE ON items_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW items
AS
  SELECT
    id,
    plaid_item_id,
    user_id,
    plaid_access_token,
    plaid_institution_id,
    status,
    created_at,
    updated_at,
    transactions_cursor,
    bank_name
  FROM
    items_table;

-- ASSETS
-- This table stores assets associated with each user
CREATE TABLE assets_table
(
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES profiles_table(id) ON DELETE CASCADE,
  value numeric(28,2),
  description text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

CREATE TRIGGER assets_updated_at_timestamp
BEFORE UPDATE ON assets_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW assets
AS
  SELECT
    id,
    user_id,
    value,
    description,
    created_at,
    updated_at
  FROM
    assets_table;

-- ACCOUNTS
-- This table stores Plaid accounts associated with each item
CREATE TABLE accounts_table
(
  id SERIAL PRIMARY KEY,
  item_id integer REFERENCES items_table(id) ON DELETE CASCADE,
  plaid_account_id text UNIQUE NOT NULL,
  name text NOT NULL,
  mask text NOT NULL,
  official_name text,
  current_balance numeric(28,10),
  available_balance numeric(28,10),
  iso_currency_code text,
  unofficial_currency_code text,
  type text NOT NULL,
  subtype text NOT NULL,
  hidden boolean DEFAULT false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

CREATE TRIGGER accounts_updated_at_timestamp
BEFORE UPDATE ON accounts_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW accounts
AS
  SELECT
    a.id,
    a.plaid_account_id,
    a.item_id,
    i.plaid_item_id,
    i.user_id,
    a.name,
    a.mask,
    a.official_name,
    a.current_balance,
    a.available_balance,
    a.iso_currency_code,
    a.unofficial_currency_code,
    a.type,
    a.subtype,
    a.hidden,
    a.created_at,
    a.updated_at
  FROM
    accounts_table a
    LEFT JOIN items_table i ON i.id = a.item_id;

-- TRANSACTIONS
-- This table stores Plaid transactions associated with each account
CREATE TABLE transactions_table
(
  id SERIAL PRIMARY KEY,
  account_id integer REFERENCES accounts_table(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles_table(id),
  amount numeric(28,10) NOT NULL,
  iso_currency_code text,
  date date NOT NULL,
  authorized_date date,
  name text NOT NULL,
  merchant_name text,
  logo_url text,
  website text,
  payment_channel text,
  transaction_id text UNIQUE NOT NULL,
  personal_finance_category text,
  personal_finance_subcategory text,
  pending boolean NOT NULL,
  pending_transaction_transaction_id text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

CREATE TRIGGER transactions_updated_at_timestamp
BEFORE UPDATE ON transactions_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW transactions
AS
  SELECT
    t.id,
    t.account_id,
    a.user_id,
    a.plaid_account_id,
    a.item_id,
    a.plaid_item_id,
    t.amount,
    t.iso_currency_code,
    t.date,
    t.authorized_date,
    t.name,
    t.merchant_name,
    t.logo_url,
    t.website,
    t.payment_channel,
    t.transaction_id,
    t.personal_finance_category,
    t.personal_finance_subcategory,
    t.pending,
    t.pending_transaction_transaction_id,
    t.created_at,
    t.updated_at
  FROM
    transactions_table t
    LEFT JOIN accounts a ON t.account_id = a.id;

-- LINK_EVENTS
-- This table logs Plaid Link client responses
CREATE TABLE link_events_table
(
  id SERIAL PRIMARY KEY,
  type text NOT NULL,
  user_id UUID,
  link_session_id text,
  request_id text UNIQUE,
  error_type text,
  error_code text,
  status text,
  created_at timestamptz default now()
);

-- PLAID_API_EVENTS
-- This table logs Plaid API server responses
CREATE TABLE plaid_api_events_table
(
  id SERIAL PRIMARY KEY,
  item_id integer,
  user_id UUID,
  plaid_method text NOT NULL,
  arguments text,
  request_id text UNIQUE,
  error_type text,
  error_code text,
  created_at timestamptz default now()
);

-- REFRESH_JOBS
-- This table manages background refresh jobs
CREATE TABLE refresh_jobs (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles_table(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  job_type TEXT NOT NULL CHECK (job_type IN ('manual', 'scheduled')),
  job_id TEXT UNIQUE,
  last_refresh_time TIMESTAMPTZ,
  next_scheduled_time TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  error_message TEXT
);

-- INDEXES
CREATE INDEX refresh_jobs_user_id_idx ON refresh_jobs(user_id);
CREATE INDEX refresh_jobs_status_idx ON refresh_jobs(status);
CREATE INDEX idx_items_plaid_item_id ON items_table(plaid_item_id);
CREATE INDEX idx_transactions_transaction_id ON transactions_table(transaction_id);
