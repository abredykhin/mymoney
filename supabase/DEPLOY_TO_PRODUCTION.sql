-- =============================================================================
-- COMPLETE PRODUCTION DATABASE SETUP
-- Run this entire script in Supabase Dashboard SQL Editor
-- Project: https://supabase.com/dashboard/project/teuyzmreoyganejfvquk/sql/new
-- =============================================================================

-- =============================================================================
-- MIGRATION 1: Initial Schema (20250101000000)
-- =============================================================================

-- Create timestamp trigger function
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- PROFILES (formerly users_table)
CREATE TABLE profiles_table
(
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE NOT NULL,
  first_name text,
  monthly_income numeric(28,2) DEFAULT 0,
  monthly_mandatory_expenses numeric(28,2) DEFAULT 0,
  spending_plan_mode text NOT NULL DEFAULT 'safe_to_spend',
  tracked_spending_categories text[] NOT NULL DEFAULT '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

ALTER TABLE profiles_table
  ADD CONSTRAINT profiles_table_spending_plan_mode_check
  CHECK (spending_plan_mode IN ('safe_to_spend', 'monthly_plan'));

CREATE TRIGGER profiles_updated_at_timestamp
BEFORE UPDATE ON profiles_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW profiles
AS
  SELECT
    id,
    username,
    first_name,
    monthly_income,
    monthly_mandatory_expenses,
    spending_plan_mode,
    tracked_spending_categories,
    created_at,
    updated_at
  FROM profiles_table;

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
  SELECT id, institution_id, name, primary_color, url, logo, updated_at
  FROM institutions_table;

-- ITEMS
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
  SELECT id, plaid_item_id, user_id, plaid_access_token, plaid_institution_id,
         status, created_at, updated_at, transactions_cursor, bank_name
  FROM items_table;

-- ASSETS
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
  SELECT id, user_id, value, description, created_at, updated_at
  FROM assets_table;

-- ACCOUNTS
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
    a.id, a.plaid_account_id, a.item_id, i.plaid_item_id, i.user_id,
    a.name, a.mask, a.official_name, a.current_balance, a.available_balance,
    a.iso_currency_code, a.unofficial_currency_code, a.type, a.subtype,
    a.hidden, a.created_at, a.updated_at
  FROM accounts_table a
  LEFT JOIN items_table i ON i.id = a.item_id;

-- TRANSACTIONS
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
    t.id, t.account_id, a.user_id, a.plaid_account_id, a.item_id, a.plaid_item_id,
    t.amount, t.iso_currency_code, t.date, t.authorized_date, t.name, t.merchant_name,
    t.logo_url, t.website, t.payment_channel, t.transaction_id,
    t.personal_finance_category, t.personal_finance_subcategory,
    t.pending, t.pending_transaction_transaction_id, t.created_at, t.updated_at
  FROM transactions_table t
  LEFT JOIN accounts a ON t.account_id = a.id;

-- LINK_EVENTS
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

-- =============================================================================
-- MIGRATION 2: Enable RLS (20250101000001)
-- =============================================================================

ALTER TABLE profiles_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE items_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE refresh_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE link_events_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE plaid_api_events_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE institutions_table ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view their own profile" ON profiles_table FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON profiles_table FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert their own profile" ON profiles_table FOR INSERT WITH CHECK (auth.uid() = id);

-- Items policies
CREATE POLICY "Users can view their own items" ON items_table FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own items" ON items_table FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own items" ON items_table FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own items" ON items_table FOR DELETE USING (auth.uid() = user_id);

-- Assets policies
CREATE POLICY "Users can view their own assets" ON assets_table FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own assets" ON assets_table FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own assets" ON assets_table FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own assets" ON assets_table FOR DELETE USING (auth.uid() = user_id);

-- Accounts policies
CREATE POLICY "Users can view their own accounts" ON accounts_table FOR SELECT
  USING (EXISTS (SELECT 1 FROM items_table WHERE items_table.id = accounts_table.item_id AND items_table.user_id = auth.uid()));
CREATE POLICY "Users can insert their own accounts" ON accounts_table FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM items_table WHERE items_table.id = accounts_table.item_id AND items_table.user_id = auth.uid()));
CREATE POLICY "Users can update their own accounts" ON accounts_table FOR UPDATE
  USING (EXISTS (SELECT 1 FROM items_table WHERE items_table.id = accounts_table.item_id AND items_table.user_id = auth.uid()));
CREATE POLICY "Users can delete their own accounts" ON accounts_table FOR DELETE
  USING (EXISTS (SELECT 1 FROM items_table WHERE items_table.id = accounts_table.item_id AND items_table.user_id = auth.uid()));

-- Transactions policies
CREATE POLICY "Users can view their own transactions" ON transactions_table FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own transactions" ON transactions_table FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own transactions" ON transactions_table FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own transactions" ON transactions_table FOR DELETE USING (auth.uid() = user_id);

-- Refresh jobs policies
CREATE POLICY "Users can view their own refresh jobs" ON refresh_jobs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own refresh jobs" ON refresh_jobs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own refresh jobs" ON refresh_jobs FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own refresh jobs" ON refresh_jobs FOR DELETE USING (auth.uid() = user_id);

-- Link events policies
CREATE POLICY "Users can view their own link events" ON link_events_table FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own link events" ON link_events_table FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Plaid API events policies
CREATE POLICY "Users can view their own API events" ON plaid_api_events_table FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own API events" ON plaid_api_events_table FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Institutions policies (reference data - all can read, only service role can modify)
CREATE POLICY "Authenticated users can view institutions" ON institutions_table FOR SELECT TO authenticated USING (true);
CREATE POLICY "Service role can insert institutions" ON institutions_table FOR INSERT TO service_role WITH CHECK (true);
CREATE POLICY "Service role can update institutions" ON institutions_table FOR UPDATE TO service_role USING (true);
CREATE POLICY "Service role can delete institutions" ON institutions_table FOR DELETE TO service_role USING (true);

-- =============================================================================
-- MIGRATION 3: Create accounts_with_banks view (20250101000002)
-- =============================================================================

CREATE OR REPLACE VIEW accounts_with_banks AS
SELECT
    a.id,
    a.item_id,
    a.name,
    a.mask,
    a.official_name,
    a.current_balance,
    a.available_balance,
    a.type,
    a.subtype,
    a.hidden,
    a.plaid_account_id as account_id,
    a.iso_currency_code,
    a.created_at,
    a.updated_at,
    -- Institution fields (joined via items)
    i.id as institution_id,
    i.name as institution_name,
    i.logo as institution_logo,
    i.primary_color as institution_color,
    i.url as institution_url,
    -- User ID from items
    it.user_id
FROM accounts_table a
JOIN items_table it ON a.item_id = it.id
JOIN institutions_table i ON it.plaid_institution_id = i.institution_id;

ALTER VIEW accounts_with_banks SET (security_invoker = true);
GRANT SELECT ON accounts_with_banks TO authenticated;

COMMENT ON VIEW accounts_with_banks IS 'View that joins accounts with their bank institution information for efficient querying by iOS app';

-- =============================================================================
-- MIGRATION: Pulse Analytics (20260523000000)
-- =============================================================================

-- Drop existing functions to ensure clean replacement
DROP FUNCTION IF EXISTS public.get_pulse_weekly_energy(date, date);
DROP FUNCTION IF EXISTS public.get_pulse_top_merchants(date, date, integer);

-- 1. Daily energy weekday spending aggregation
CREATE OR REPLACE FUNCTION public.get_pulse_weekly_energy(
    week_start DATE,
    week_end DATE
)
RETURNS TABLE (
    weekday TEXT,
    date_label DATE,
    total_spent DOUBLE PRECISION,
    is_peak BOOLEAN,
    peak_merchant TEXT,
    peak_category TEXT,
    peak_amount DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    peak_date DATE;
BEGIN
    -- Find the day in the range with the absolute highest spending
    SELECT COALESCE(t.authorized_date, t.date) INTO peak_date
    FROM public.transactions_table t
    WHERE t.user_id = auth.uid()
      AND COALESCE(t.authorized_date, t.date) BETWEEN week_start AND week_end
      AND t.amount > 0
      AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    GROUP BY COALESCE(t.authorized_date, t.date)
    ORDER BY SUM(t.amount) DESC
    LIMIT 1;

    -- Return daily stats along with peak transaction details
    RETURN QUERY
    WITH daily_totals AS (
        SELECT 
            COALESCE(t.authorized_date, t.date) as t_date,
            SUM(t.amount)::double precision as t_sum
        FROM public.transactions_table t
        WHERE t.user_id = auth.uid()
          AND COALESCE(t.authorized_date, t.date) BETWEEN week_start AND week_end
          AND t.amount > 0
          AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
        GROUP BY COALESCE(t.authorized_date, t.date)
    ),
    peak_transactions AS (
        SELECT DISTINCT ON (COALESCE(t.authorized_date, t.date))
            COALESCE(t.authorized_date, t.date) as t_date,
            COALESCE(t.merchant_name, t.name) as merchant,
            t.personal_finance_category as category,
            t.amount::double precision as amount
        FROM public.transactions_table t
        WHERE t.user_id = auth.uid()
          AND COALESCE(t.authorized_date, t.date) BETWEEN week_start AND week_end
          AND t.amount > 0
        ORDER BY COALESCE(t.authorized_date, t.date), t.amount DESC
    )
    SELECT 
        TO_CHAR(d.date_series, 'Dy') as weekday,
        d.date_series::date as date_label,
        COALESCE(dt.t_sum, 0.0)::double precision as total_spent,
        (d.date_series::date = peak_date) as is_peak,
        COALESCE(pt.merchant, 'No Spend') as peak_merchant,
        pt.category as peak_category,
        COALESCE(pt.amount, 0.0)::double precision as peak_amount
    FROM 
        GENERATE_SERIES(week_start::timestamp, week_end::timestamp, '1 day'::interval) d(date_series)
    LEFT JOIN daily_totals dt ON dt.t_date = d.date_series::date
    LEFT JOIN peak_transactions pt ON pt.t_date = d.date_series::date
    ORDER BY d.date_series ASC;
END;
$$;

-- 2. Ranked Top Merchants (The Lineup)
CREATE OR REPLACE FUNCTION public.get_pulse_top_merchants(
    start_date DATE,
    end_date DATE,
    lim INTEGER DEFAULT 5
)
RETURNS TABLE (
    merchant_name TEXT,
    total_spent DOUBLE PRECISION,
    transaction_count BIGINT,
    personal_finance_category TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(t.merchant_name, t.name) as merchant_name,
        SUM(t.amount)::double precision as total_spent,
        COUNT(*)::bigint as transaction_count,
        MIN(t.personal_finance_category) as personal_finance_category
    FROM 
        public.transactions_table t
    WHERE 
        t.user_id = auth.uid()
        AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
        AND t.amount > 0
        AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    GROUP BY 
        COALESCE(t.merchant_name, t.name)
    ORDER BY 
        total_spent DESC
    LIMIT 
        lim;
END;
$$;

-- =============================================================================
-- Migration: 20260523000002 — Onboarding tracked categories
-- =============================================================================

ALTER TABLE profiles_table
  ADD COLUMN IF NOT EXISTS tracked_spending_categories text[] NOT NULL DEFAULT '{}';

-- =============================================================================
-- Migration: 20260523202336 — Add profile first name
-- =============================================================================

ALTER TABLE public.profiles_table
  ADD COLUMN IF NOT EXISTS first_name text;

CREATE OR REPLACE VIEW public.profiles
WITH (security_invoker = true)
AS
  SELECT
    id,
    username,
    monthly_income,
    monthly_mandatory_expenses,
    created_at,
    updated_at,
    tracked_spending_categories,
    first_name,
    spending_plan_mode
  FROM
    public.profiles_table;

-- =============================================================================
-- Migration: 20260524200054 — Add spending plan mode to profiles
-- =============================================================================

ALTER TABLE public.profiles_table
    ADD COLUMN IF NOT EXISTS spending_plan_mode text NOT NULL DEFAULT 'safe_to_spend';

ALTER TABLE public.profiles_table
    DROP CONSTRAINT IF EXISTS profiles_table_spending_plan_mode_check;

ALTER TABLE public.profiles_table
    ADD CONSTRAINT profiles_table_spending_plan_mode_check
    CHECK (spending_plan_mode IN ('safe_to_spend', 'monthly_plan'));

CREATE OR REPLACE VIEW public.profiles
WITH (security_invoker = true)
AS
  SELECT
    id,
    username,
    monthly_income,
    monthly_mandatory_expenses,
    created_at,
    updated_at,
    tracked_spending_categories,
    first_name,
    spending_plan_mode
  FROM
    public.profiles_table;

-- =============================================================================
-- Migration: 20260524190944 — Exclude manual rent mortgage subscription label
-- =============================================================================

CREATE OR REPLACE VIEW public.active_subscription_streams
WITH (security_invoker = true)
AS
SELECT *
FROM public.recurring_streams_table
WHERE type = 'expense'
  AND is_active = true
  AND is_excluded = false
  AND status <> 'TOMBSTONED'
  AND COALESCE(personal_finance_category, '') NOT IN (
    'RENT_OR_MORTGAGE'
  )
  AND COALESCE(personal_finance_subcategory, '') NOT IN (
    'RENT_AND_UTILITIES_RENT',
    'RENT_OR_MORTGAGE'
  )
  AND LOWER(BTRIM(COALESCE(merchant_name, ''))) NOT IN (
    'rent',
    'rent payment',
    'rent / mortgage',
    'apartment rent',
    'mortgage',
    'mortgage payment'
  )
  AND LOWER(BTRIM(description)) NOT IN (
    'rent',
    'rent payment',
    'rent / mortgage',
    'apartment rent',
    'mortgage',
    'mortgage payment'
  );

GRANT SELECT ON public.active_subscription_streams TO authenticated;

-- =============================================================================
-- Migration: 20260524192339 — Spendable income transactions view
-- =============================================================================

CREATE OR REPLACE VIEW public.spendable_income_transactions
WITH (security_invoker = true)
AS
SELECT t.*
FROM public.transactions t
WHERE t.amount < 0
  AND COALESCE(t.type, '') NOT IN ('credit', 'loan')
  AND t.personal_finance_category = 'INCOME'
  AND NOT (
    COALESCE(t.name, '') ILIKE ANY (ARRAY[
      '%transfer%',
      '%wire%',
      '%reversal%',
      '%brokerage%',
      '%bkrg%',
      '%schwab%',
      '%moneylink%',
      '%invest%',
      '%healthequity%'
    ])
    OR COALESCE(t.merchant_name, '') ILIKE ANY (ARRAY[
      '%transfer%',
      '%wire%',
      '%reversal%',
      '%brokerage%',
      '%bkrg%',
      '%schwab%',
      '%moneylink%',
      '%invest%',
      '%healthequity%'
    ])
  );

GRANT SELECT ON public.spendable_income_transactions TO authenticated;

-- =============================================================================
-- Migration: 20260524192715 — Active mandatory expense streams view
-- =============================================================================

CREATE OR REPLACE VIEW public.active_mandatory_expense_streams
WITH (security_invoker = true)
AS
SELECT rs.*
FROM public.recurring_streams_table rs
WHERE rs.type = 'expense'
  AND rs.is_active = true
  AND rs.is_excluded = false
  AND rs.status <> 'TOMBSTONED'
  AND NOT (
    rs.is_manual = true
    AND LOWER(BTRIM(rs.description)) IN (
      'rent',
      'rent payment',
      'rent / mortgage',
      'apartment rent',
      'mortgage',
      'mortgage payment'
    )
    AND EXISTS (
      SELECT 1
      FROM public.recurring_streams_table auto_rs
      WHERE auto_rs.user_id = rs.user_id
        AND auto_rs.type = 'expense'
        AND auto_rs.is_active = true
        AND auto_rs.is_excluded = false
        AND auto_rs.is_manual = false
        AND auto_rs.status <> 'TOMBSTONED'
        AND (
          auto_rs.personal_finance_subcategory IN (
            'RENT_AND_UTILITIES_RENT',
            'RENT_OR_MORTGAGE'
          )
          OR LOWER(BTRIM(COALESCE(auto_rs.merchant_name, ''))) IN (
            'rent',
            'rent payment',
            'rent / mortgage',
            'apartment rent',
            'mortgage',
            'mortgage payment'
          )
          OR LOWER(BTRIM(auto_rs.description)) IN (
            'rent',
            'rent payment',
            'rent / mortgage',
            'apartment rent',
            'mortgage',
            'mortgage payment'
          )
        )
    )
  );

GRANT SELECT ON public.active_mandatory_expense_streams TO authenticated;
GRANT SELECT ON public.active_mandatory_expense_streams TO service_role;

-- =============================================================================
-- DONE! Database is ready for the iOS app.
-- =============================================================================
