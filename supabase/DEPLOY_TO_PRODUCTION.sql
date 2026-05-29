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
      AND (t.personal_finance_category IS NULL OR t.personal_finance_category != 'TRANSFER_IN')
      AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
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
          AND (t.personal_finance_category IS NULL OR t.personal_finance_category != 'TRANSFER_IN')
          AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
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
        AND (t.personal_finance_category IS NULL OR t.personal_finance_category != 'TRANSFER_IN')
        AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
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
    'RENT_OR_MORTGAGE',
    'RENT_AND_UTILITIES',
    'LOAN_PAYMENTS'
  )
  AND COALESCE(personal_finance_subcategory, '') NOT IN (
    'RENT_AND_UTILITIES_RENT',
    'RENT_OR_MORTGAGE',
    'GENERAL_SERVICES_INSURANCE',
    'GENERAL_SERVICES_AUTOMOTIVE'
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
  AND COALESCE(rs.personal_finance_subcategory, '') <> 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
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
-- Migration: 20260525000003 — Align spending streak daily limit calculation
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_user_spending_streak()
RETURNS TABLE (
    current_streak INT,
    max_streak INT,
    last_10_days_status BOOLEAN[]
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    income_val NUMERIC(28,2);
    actual_income NUMERIC(28,2);
    fixed_exp NUMERIC(28,2);
    daily_limit NUMERIC(28,2);
    streak_count INT := 0;
    max_streak_count INT := 0;
    temp_streak INT := 0;
    day_idx INT;
    spend_on_day NUMERIC(28,2);
    status_arr BOOLEAN[] := '{}';
    day_date DATE;
    current_streak_set BOOLEAN := FALSE;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.items_table
        WHERE user_id = (SELECT auth.uid())
          AND is_active = TRUE
    ) THEN
        RETURN;
    END IF;

    -- 1. Fetch expected profile values
    SELECT COALESCE(monthly_income, 0), COALESCE(monthly_mandatory_expenses, 0)
    INTO income_val, fixed_exp
    FROM public.profiles_table
    WHERE id = (SELECT auth.uid());

    -- 2. Fetch actual spendable income received this month
    SELECT COALESCE(SUM(ABS(amount)), 0)
    INTO actual_income
    FROM public.spendable_income_transactions
    WHERE user_id = (SELECT auth.uid())
      AND date >= DATE_TRUNC('month', CURRENT_DATE)::DATE
      AND date <= (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    -- 3. Use the greatest of profile expected monthly income or actual paychecks received
    income_val := GREATEST(income_val, actual_income);

    daily_limit := (income_val - fixed_exp) / 30.0;
    IF daily_limit <= 0 THEN
        daily_limit := 50.00;
    END IF;

    FOR day_idx IN 0..89 LOOP
        day_date := CURRENT_DATE - day_idx;

        SELECT COALESCE(SUM(amount), 0)
        INTO spend_on_day
        FROM public.transactions_table
        WHERE user_id = (SELECT auth.uid())
          AND COALESCE(authorized_date, date) = day_date
          AND amount > 0
          AND (personal_finance_category IS NULL OR personal_finance_category != 'TRANSFER_IN')
          AND COALESCE(personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT';

        IF spend_on_day <= daily_limit THEN
            temp_streak := temp_streak + 1;
            IF day_idx < 10 THEN
                status_arr := array_append(status_arr, TRUE);
            END IF;
        ELSE
            -- We hit an over-budget day.
            -- The first over-budget day we encounter going backwards from today determines the end of the current active streak.
            IF NOT current_streak_set THEN
                streak_count := temp_streak;
                current_streak_set := TRUE;
            END IF;

            IF temp_streak > max_streak_count THEN
                max_streak_count := temp_streak;
            END IF;

            temp_streak := 0;
            IF day_idx < 10 THEN
                status_arr := array_append(status_arr, FALSE);
            END IF;
        END IF;
    END LOOP;

    -- If the streak was never broken (e.g., under budget for all 90 days), set it to the total accumulated.
    IF NOT current_streak_set THEN
        streak_count := temp_streak;
    END IF;

    IF temp_streak > max_streak_count THEN
        max_streak_count := temp_streak;
    END IF;

    RETURN QUERY SELECT streak_count, max_streak_count, status_arr;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_user_spending_streak() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_spending_streak() TO authenticated;

-- =============================================================================
-- Migration: 20260525000004 — Fix transaction stats filtering (Legitimate Bill Bug Fix)
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_monthly_transaction_stats(date, date);
DROP FUNCTION IF EXISTS public.get_daily_transaction_stats(date, date);

-- 1. Redefine public.get_monthly_transaction_stats
CREATE OR REPLACE FUNCTION public.get_monthly_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (
  year double precision,
  month double precision,
  total_in double precision,
  total_out double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    -- Use authorized_date if available, otherwise fall back to date
    EXTRACT(YEAR FROM COALESCE(t.authorized_date, t.date))::double precision as year,
    EXTRACT(MONTH FROM COALESCE(t.authorized_date, t.date))::double precision as month,
    COALESCE(SUM(
      CASE
        -- Loan: Positive is Advance (In)
        WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
        -- Depository/Investment: Negative is Deposit (In)
        -- This excludes credit cards - payments to credit cards are NOT income
        WHEN (a.type ILIKE 'depository' OR a.type ILIKE 'investment') AND t.amount < 0 THEN ABS(t.amount)
        ELSE 0
      END
    ), 0)::double precision as total_in,
    COALESCE(SUM(
      CASE
        -- Loan: Negative is Payment (Out)
        WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        -- Investment: Exclude positive amounts (Stock buys are NOT spending)
        WHEN a.type ILIKE 'investment' THEN 0
        -- All other accounts (Depository, Credit): Positive is Expense (Out)
        WHEN t.amount > 0 THEN t.amount
        ELSE 0
      END
    ), 0)::double precision as total_out
  FROM
    public.transactions_table t
  JOIN
    public.accounts_table a ON t.account_id = a.id
  WHERE
    t.user_id = auth.uid()
    -- Use authorized_date if available, otherwise fall back to date
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    -- Exclude transfers and credit card payments completely
    AND (
      -- Legitimate spending: exclude only TRANSFER_IN and credit card payments
      (
        t.personal_finance_category IS NOT NULL
        AND t.personal_finance_category != 'TRANSFER_IN'
        AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
      )
      OR
      -- Unclassified category: only include if the name doesn't look like a payment/transfer
      (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
    -- Exclude brokerage/transfer/reversal-like transactions even if classified as INCOME
    AND NOT (
      t.personal_finance_category = 'INCOME'
      AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
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
    )
  GROUP BY
    1, 2
  ORDER BY
    1 DESC, 2 DESC;
END;
$$;

-- 2. Redefine public.get_daily_transaction_stats
CREATE OR REPLACE FUNCTION public.get_daily_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (
  date date,
  total_in double precision,
  total_out double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    -- Use authorized_date if available, otherwise fall back to date
    COALESCE(t.authorized_date, t.date) as date,
    COALESCE(SUM(
      CASE
        -- Loan: Positive is Advance (In)
        WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
        -- Depository/Investment: Negative is Deposit (In)
        -- This excludes credit cards - payments to credit cards are NOT income
        WHEN (a.type ILIKE 'depository' OR a.type ILIKE 'investment') AND t.amount < 0 THEN ABS(t.amount)
        ELSE 0
      END
    ), 0)::double precision as total_in,
    COALESCE(SUM(
      CASE
        -- Loan: Negative is Payment (Out)
        WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        -- Investment: Exclude positive amounts (Stock buys are NOT spending)
        WHEN a.type ILIKE 'investment' THEN 0
        -- All other accounts (Depository, Credit): Positive is Expense (Out)
        WHEN t.amount > 0 THEN t.amount
        ELSE 0
      END
    ), 0)::double precision as total_out
  FROM
    public.transactions_table t
  JOIN
    public.accounts_table a ON t.account_id = a.id
  WHERE
    t.user_id = auth.uid()
    -- Use authorized_date if available, otherwise fall back to date
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    -- Exclude transfers and credit card payments completely
    AND (
      -- Legitimate spending: exclude only TRANSFER_IN and credit card payments
      (
        t.personal_finance_category IS NOT NULL
        AND t.personal_finance_category != 'TRANSFER_IN'
        AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
      )
      OR
      -- Unclassified category: only include if the name doesn't look like a payment/transfer
      (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
    -- Exclude brokerage/transfer/reversal-like transactions even if classified as INCOME
    AND NOT (
      t.personal_finance_category = 'INCOME'
      AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
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
    )
  GROUP BY
    1
  ORDER BY
    1 DESC;
END;
$$;

ALTER FUNCTION public.get_monthly_transaction_stats(date, date) SECURITY DEFINER;
REVOKE EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) TO authenticated;

ALTER FUNCTION public.get_daily_transaction_stats(date, date) SECURITY DEFINER;
REVOKE EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) TO authenticated;

-- =============================================================================
-- variable_transactions view
-- Non-recurring transactions filtered to exclude only TRANSFER_IN and CC payments.
-- =============================================================================

CREATE OR REPLACE VIEW variable_transactions AS
SELECT t.*
FROM transactions t
WHERE
  (t.is_recurring = FALSE OR t.is_recurring IS NULL)
  AND t.personal_finance_category != 'TRANSFER_IN'
  AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT';

ALTER VIEW variable_transactions SET (security_invoker = true);

-- =============================================================================
-- Migration: 20260525171917 — Canonical spend_date column
-- =============================================================================

CREATE OR REPLACE FUNCTION public.compute_transaction_spend_date(
  tx_date date,
  tx_authorized_date date,
  tx_pending boolean,
  tx_created_at timestamptz,
  local_timezone text DEFAULT 'America/Los_Angeles'
)
RETURNS date
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT
    CASE
      WHEN COALESCE(tx_authorized_date, tx_date) IS NULL THEN NULL
      WHEN COALESCE(tx_pending, false)
        AND tx_created_at IS NOT NULL
        AND COALESCE(tx_authorized_date, tx_date) > (tx_created_at AT TIME ZONE local_timezone)::date
        THEN (tx_created_at AT TIME ZONE local_timezone)::date
      ELSE COALESCE(tx_authorized_date, tx_date)
    END;
$$;

ALTER TABLE public.transactions_table
  ADD COLUMN IF NOT EXISTS spend_date date;

UPDATE public.transactions_table
SET spend_date = public.compute_transaction_spend_date(date, authorized_date, pending, created_at)
WHERE spend_date IS DISTINCT FROM public.compute_transaction_spend_date(date, authorized_date, pending, created_at);

CREATE OR REPLACE FUNCTION public.set_transaction_spend_date()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.spend_date := public.compute_transaction_spend_date(
    NEW.date,
    NEW.authorized_date,
    NEW.pending,
    COALESCE(NEW.created_at, now())
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_transaction_spend_date_trigger ON public.transactions_table;
CREATE TRIGGER set_transaction_spend_date_trigger
BEFORE INSERT OR UPDATE OF date, authorized_date, pending, created_at
ON public.transactions_table
FOR EACH ROW
EXECUTE FUNCTION public.set_transaction_spend_date();

CREATE INDEX IF NOT EXISTS idx_transactions_table_user_spend_date
  ON public.transactions_table (user_id, spend_date DESC)
  WHERE spend_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_table_account_spend_date
  ON public.transactions_table (account_id, spend_date DESC)
  WHERE spend_date IS NOT NULL;

-- =============================================================================
-- Migration: 20260525220000 — Include TRANSFER_OUT_OTHER_TRANSFER_OUT and
--                              TRANSFER_IN_ACCOUNT_TRANSFER in spend/income
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_daily_transaction_stats(date, date);
DROP FUNCTION IF EXISTS public.get_monthly_transaction_stats(date, date);

CREATE OR REPLACE FUNCTION public.get_daily_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (date date, total_in double precision, total_out double precision)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(t.authorized_date, t.date) as date,
    COALESCE(SUM(CASE
      WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
      WHEN (a.type ILIKE 'depository' OR a.type ILIKE 'investment') AND t.amount < 0 THEN ABS(t.amount)
      ELSE 0
    END), 0)::double precision as total_in,
    COALESCE(SUM(CASE
      WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
      WHEN a.type ILIKE 'investment' THEN 0
      WHEN t.amount > 0 THEN t.amount
      ELSE 0
    END), 0)::double precision as total_out
  FROM public.transactions_table t
  JOIN public.accounts_table a ON t.account_id = a.id
  WHERE t.user_id = auth.uid()
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    AND (
      (
        t.personal_finance_category IS NOT NULL
        AND NOT (
          t.personal_finance_category = 'TRANSFER_IN'
          AND COALESCE(t.personal_finance_subcategory, '') != 'TRANSFER_IN_ACCOUNT_TRANSFER'
        )
        AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
        AND NOT (
          t.personal_finance_category = 'TRANSFER_OUT'
          AND COALESCE(t.personal_finance_subcategory, '') NOT IN (
            'TRANSFER_OUT_ACCOUNT_TRANSFER',
            'TRANSFER_OUT_WITHDRAWAL',
            'TRANSFER_OUT_OTHER_TRANSFER_OUT'
          )
        )
      )
      OR (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
    AND NOT (
      t.personal_finance_category = 'INCOME'
      AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
        '%transfer%', '%wire%', '%reversal%', '%brokerage%',
        '%bkrg%', '%schwab%', '%moneylink%', '%invest%', '%healthequity%'
      ])
    )
  GROUP BY 1 ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_monthly_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (year double precision, month double precision, total_in double precision, total_out double precision)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    EXTRACT(YEAR FROM COALESCE(t.authorized_date, t.date))::double precision,
    EXTRACT(MONTH FROM COALESCE(t.authorized_date, t.date))::double precision,
    COALESCE(SUM(CASE
      WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
      WHEN (a.type ILIKE 'depository' OR a.type ILIKE 'investment') AND t.amount < 0 THEN ABS(t.amount)
      ELSE 0
    END), 0)::double precision,
    COALESCE(SUM(CASE
      WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
      WHEN a.type ILIKE 'investment' THEN 0
      WHEN t.amount > 0 THEN t.amount
      ELSE 0
    END), 0)::double precision
  FROM public.transactions_table t
  JOIN public.accounts_table a ON t.account_id = a.id
  WHERE t.user_id = auth.uid()
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    AND (
      (
        t.personal_finance_category IS NOT NULL
        AND NOT (
          t.personal_finance_category = 'TRANSFER_IN'
          AND COALESCE(t.personal_finance_subcategory, '') != 'TRANSFER_IN_ACCOUNT_TRANSFER'
        )
        AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
        AND NOT (
          t.personal_finance_category = 'TRANSFER_OUT'
          AND COALESCE(t.personal_finance_subcategory, '') NOT IN (
            'TRANSFER_OUT_ACCOUNT_TRANSFER',
            'TRANSFER_OUT_WITHDRAWAL',
            'TRANSFER_OUT_OTHER_TRANSFER_OUT'
          )
        )
      )
      OR (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
    AND NOT (
      t.personal_finance_category = 'INCOME'
      AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
        '%transfer%', '%wire%', '%reversal%', '%brokerage%',
        '%bkrg%', '%schwab%', '%moneylink%', '%invest%', '%healthequity%'
      ])
    )
  GROUP BY 1, 2 ORDER BY 1 DESC, 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) TO authenticated;

-- =============================================================================
-- Migration: 20260525230000 — Add is_spend / is_income to transactions view
-- =============================================================================

CREATE OR REPLACE VIEW public.transactions
WITH (security_invoker = true)
AS
SELECT
  t.id,
  t.account_id,
  a.user_id,
  a.plaid_account_id,
  a.item_id,
  a.plaid_item_id,
  a.type,
  t.amount,
  t.is_recurring,
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
  t.updated_at,
  t.spend_date,
  (
    t.amount > 0
    AND COALESCE(a.type, '') NOT ILIKE 'investment'
    AND (
      (
        t.personal_finance_category IS NOT NULL
        AND NOT (
          t.personal_finance_category = 'TRANSFER_IN'
          AND COALESCE(t.personal_finance_subcategory, '') != 'TRANSFER_IN_ACCOUNT_TRANSFER'
        )
        AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
        AND NOT (
          t.personal_finance_category = 'TRANSFER_OUT'
          AND COALESCE(t.personal_finance_subcategory, '') NOT IN (
            'TRANSFER_OUT_ACCOUNT_TRANSFER',
            'TRANSFER_OUT_WITHDRAWAL',
            'TRANSFER_OUT_OTHER_TRANSFER_OUT'
          )
        )
        AND NOT (
          t.personal_finance_category = 'INCOME'
          AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
            '%transfer%', '%wire%', '%reversal%', '%brokerage%',
            '%bkrg%', '%schwab%', '%moneylink%', '%invest%', '%healthequity%'
          ])
        )
      )
      OR (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
  ) AS is_spend,
  (
    t.amount < 0
    AND COALESCE(a.type, '') NOT ILIKE 'credit'
    AND COALESCE(a.type, '') NOT ILIKE 'loan'
    AND (
      t.personal_finance_subcategory = 'TRANSFER_IN_ACCOUNT_TRANSFER'
      OR (
        t.personal_finance_category = 'INCOME'
        AND NOT (
          COALESCE(t.name, '') ILIKE ANY (ARRAY[
            '%transfer%', '%wire%', '%reversal%', '%brokerage%',
            '%bkrg%', '%schwab%', '%moneylink%', '%invest%', '%healthequity%'
          ])
        )
      )
    )
  ) AS is_income
FROM public.transactions_table t
LEFT JOIN public.accounts a ON t.account_id = a.id;

-- =============================================================================
-- Migration: 20260525240000 — Simplify all functions/views to use is_spend
-- =============================================================================

CREATE OR REPLACE VIEW public.variable_transactions
WITH (security_invoker = true)
AS
SELECT t.*
FROM public.transactions t
WHERE t.is_spend
  AND (t.is_recurring = FALSE OR t.is_recurring IS NULL);

DROP FUNCTION IF EXISTS public.get_daily_transaction_stats(date, date);
CREATE OR REPLACE FUNCTION public.get_daily_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (date date, total_in double precision, total_out double precision)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.spend_date::date AS date,
    COALESCE(SUM(CASE WHEN t.is_income THEN ABS(t.amount) ELSE 0 END), 0)::double precision AS total_in,
    COALESCE(SUM(CASE WHEN t.is_spend  THEN t.amount       ELSE 0 END), 0)::double precision AS total_out
  FROM public.transactions t
  WHERE t.user_id = auth.uid()
    AND t.spend_date BETWEEN start_date AND end_date
    AND (t.is_spend OR t.is_income)
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) TO authenticated;

DROP FUNCTION IF EXISTS public.get_monthly_transaction_stats(date, date);
CREATE OR REPLACE FUNCTION public.get_monthly_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (year double precision, month double precision, total_in double precision, total_out double precision)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    EXTRACT(YEAR FROM t.spend_date)::double precision,
    EXTRACT(MONTH FROM t.spend_date)::double precision,
    COALESCE(SUM(CASE WHEN t.is_income THEN ABS(t.amount) ELSE 0 END), 0)::double precision,
    COALESCE(SUM(CASE WHEN t.is_spend  THEN t.amount       ELSE 0 END), 0)::double precision
  FROM public.transactions t
  WHERE t.user_id = auth.uid()
    AND t.spend_date BETWEEN start_date AND end_date
    AND (t.is_spend OR t.is_income)
  GROUP BY 1, 2
  ORDER BY 1 DESC, 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_user_spending_streak()
RETURNS TABLE (current_streak INT, max_streak INT, last_10_days_status BOOLEAN[])
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
DECLARE
    income_val NUMERIC(28,2); actual_income NUMERIC(28,2); fixed_exp NUMERIC(28,2);
    daily_limit NUMERIC(28,2); streak_count INT := 0; max_streak_count INT := 0;
    temp_streak INT := 0; day_idx INT; spend_on_day NUMERIC(28,2);
    status_arr BOOLEAN[] := '{}'; day_date DATE; current_streak_set BOOLEAN := FALSE;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.items_table WHERE user_id = (SELECT auth.uid()) AND is_active = TRUE
    ) THEN RETURN; END IF;

    SELECT COALESCE(monthly_income, 0), COALESCE(monthly_mandatory_expenses, 0)
    INTO income_val, fixed_exp
    FROM public.profiles_table WHERE id = (SELECT auth.uid());

    SELECT COALESCE(SUM(ABS(amount)), 0) INTO actual_income
    FROM public.spendable_income_transactions
    WHERE user_id = (SELECT auth.uid())
      AND date >= DATE_TRUNC('month', CURRENT_DATE)::DATE
      AND date <= (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    income_val := GREATEST(income_val, actual_income);
    daily_limit := (income_val - fixed_exp) / 30.0;
    IF daily_limit <= 0 THEN daily_limit := 50.00; END IF;

    FOR day_idx IN 0..89 LOOP
        day_date := CURRENT_DATE - day_idx;
        SELECT COALESCE(SUM(t.amount), 0) INTO spend_on_day
        FROM public.transactions t
        WHERE t.user_id = (SELECT auth.uid())
          AND t.spend_date = day_date
          AND t.is_spend;

        IF spend_on_day <= daily_limit THEN
            temp_streak := temp_streak + 1;
            IF day_idx < 10 THEN status_arr := array_append(status_arr, TRUE); END IF;
        ELSE
            IF NOT current_streak_set THEN streak_count := temp_streak; current_streak_set := TRUE; END IF;
            IF temp_streak > max_streak_count THEN max_streak_count := temp_streak; END IF;
            temp_streak := 0;
            IF day_idx < 10 THEN status_arr := array_append(status_arr, FALSE); END IF;
        END IF;
    END LOOP;

    IF NOT current_streak_set THEN streak_count := temp_streak; END IF;
    IF temp_streak > max_streak_count THEN max_streak_count := temp_streak; END IF;
    RETURN QUERY SELECT streak_count, max_streak_count, status_arr;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_user_spending_streak() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_spending_streak() TO authenticated;

DROP FUNCTION IF EXISTS public.get_pulse_weekly_energy(date, date);
CREATE OR REPLACE FUNCTION public.get_pulse_weekly_energy(week_start DATE, week_end DATE)
RETURNS TABLE (weekday TEXT, date_label DATE, total_spent DOUBLE PRECISION,
               is_peak BOOLEAN, peak_merchant TEXT, peak_category TEXT, peak_amount DOUBLE PRECISION)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
DECLARE peak_date DATE;
BEGIN
    SELECT t.spend_date INTO peak_date
    FROM public.transactions t
    WHERE t.user_id = auth.uid()
      AND t.spend_date BETWEEN week_start AND week_end
      AND t.is_spend
    GROUP BY t.spend_date
    ORDER BY SUM(t.amount) DESC LIMIT 1;

    RETURN QUERY
    WITH daily_totals AS (
        SELECT t.spend_date AS t_date, SUM(t.amount)::double precision AS t_sum
        FROM public.transactions t
        WHERE t.user_id = auth.uid()
          AND t.spend_date BETWEEN week_start AND week_end
          AND t.is_spend
        GROUP BY t.spend_date
    ),
    peak_transactions AS (
        SELECT DISTINCT ON (t.spend_date)
            t.spend_date AS t_date,
            COALESCE(t.merchant_name, t.name) AS merchant,
            t.personal_finance_category AS category,
            t.amount::double precision AS amount
        FROM public.transactions t
        WHERE t.user_id = auth.uid()
          AND t.spend_date BETWEEN week_start AND week_end
          AND t.is_spend
        ORDER BY t.spend_date, t.amount DESC
    )
    SELECT TO_CHAR(d.date_series, 'Dy'), d.date_series::date,
           COALESCE(dt.t_sum, 0.0)::double precision, (d.date_series::date = peak_date),
           COALESCE(pt.merchant, 'No Spend'), pt.category, COALESCE(pt.amount, 0.0)::double precision
    FROM GENERATE_SERIES(week_start::timestamp, week_end::timestamp, '1 day'::interval) d(date_series)
    LEFT JOIN daily_totals dt ON dt.t_date = d.date_series::date
    LEFT JOIN peak_transactions pt ON pt.t_date = d.date_series::date
    ORDER BY d.date_series ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) TO authenticated;

DROP FUNCTION IF EXISTS public.get_pulse_top_merchants(date, date, integer);
CREATE OR REPLACE FUNCTION public.get_pulse_top_merchants(start_date DATE, end_date DATE, lim INTEGER DEFAULT 5)
RETURNS TABLE (merchant_name TEXT, total_spent DOUBLE PRECISION, transaction_count BIGINT, personal_finance_category TEXT)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT COALESCE(t.merchant_name, t.name), SUM(t.amount)::double precision,
           COUNT(*)::bigint, MIN(t.personal_finance_category)
    FROM public.transactions t
    WHERE t.user_id = auth.uid()
      AND t.spend_date BETWEEN start_date AND end_date
      AND t.is_spend
    GROUP BY COALESCE(t.merchant_name, t.name)
    ORDER BY total_spent DESC LIMIT lim;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) TO authenticated;

-- =============================================================================
-- Migration: 20260525250000 — Exclude wire transfers from variable_transactions
-- =============================================================================

-- TRANSFER_OUT_OTHER_TRANSFER_OUT (wire transfers) are real money-out and appear
-- in damage report stats via is_spend = true, but they are NOT discretionary
-- variable spending and must not inflate the liquid hero budget widget.

CREATE OR REPLACE VIEW public.variable_transactions
WITH (security_invoker = true)
AS
SELECT t.*
FROM public.transactions t
WHERE t.is_spend
  AND (t.is_recurring = FALSE OR t.is_recurring IS NULL)
  AND COALESCE(t.personal_finance_subcategory, '') != 'TRANSFER_OUT_OTHER_TRANSFER_OUT';

-- =============================================================================
-- Migration: 20260529052035 — Refine spend/income classification
-- =============================================================================

-- Credit-card payments from checking are only duplicate spend when the matching
-- target credit/loan account is linked. HealthEquity is not excluded by merchant
-- name because Plaid can classify legitimate employer inflows as INCOME_WAGES.

CREATE OR REPLACE VIEW public.transactions
WITH (security_invoker = true)
AS
SELECT
  t.id,
  t.account_id,
  a.user_id,
  a.plaid_account_id,
  a.item_id,
  a.plaid_item_id,
  a.type,
  t.amount,
  t.is_recurring,
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
  t.updated_at,
  t.spend_date,

  (
    t.amount > 0
    AND COALESCE(a.type, '') NOT ILIKE 'investment'
    AND (
      (
        t.personal_finance_category IS NOT NULL
        AND NOT (
          t.personal_finance_category = 'TRANSFER_IN'
          AND COALESCE(t.personal_finance_subcategory, '') != 'TRANSFER_IN_ACCOUNT_TRANSFER'
        )
        AND NOT (
          COALESCE(t.personal_finance_subcategory, '') = 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
          AND EXISTS (
            SELECT 1
            FROM public.transactions_table ct
            JOIN public.accounts ca ON ct.account_id = ca.id
            WHERE ca.user_id = a.user_id
              AND COALESCE(ca.type, '') IN ('credit', 'loan')
              AND ct.amount < 0
              AND ABS(ct.amount + t.amount) < 0.005
              AND COALESCE(ct.spend_date, ct.authorized_date, ct.date)
                  BETWEEN (t.spend_date - INTERVAL '3 days')::date
                      AND (t.spend_date + INTERVAL '3 days')::date
          )
        )
        AND NOT (
          t.personal_finance_category = 'TRANSFER_OUT'
          AND COALESCE(t.personal_finance_subcategory, '') NOT IN (
            'TRANSFER_OUT_ACCOUNT_TRANSFER',
            'TRANSFER_OUT_WITHDRAWAL',
            'TRANSFER_OUT_OTHER_TRANSFER_OUT'
          )
        )
        AND NOT (
          t.personal_finance_category = 'INCOME'
          AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
            '%transfer%', '%wire%', '%reversal%', '%brokerage%',
            '%bkrg%', '%schwab%', '%moneylink%', '%invest%'
          ])
        )
      )
      OR (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
  ) AS is_spend,

  (
    t.amount < 0
    AND COALESCE(a.type, '') NOT ILIKE 'credit'
    AND COALESCE(a.type, '') NOT ILIKE 'loan'
    AND (
      t.personal_finance_subcategory = 'TRANSFER_IN_ACCOUNT_TRANSFER'
      OR (
        t.personal_finance_category = 'INCOME'
        AND NOT (
          COALESCE(t.name, '') ILIKE ANY (ARRAY[
            '%transfer%', '%wire%', '%reversal%', '%brokerage%',
            '%bkrg%', '%schwab%', '%moneylink%', '%invest%'
          ])
        )
      )
    )
  ) AS is_income

FROM public.transactions_table t
LEFT JOIN public.accounts a ON t.account_id = a.id;

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
      '%invest%'
    ])
    OR COALESCE(t.merchant_name, '') ILIKE ANY (ARRAY[
      '%transfer%',
      '%wire%',
      '%reversal%',
      '%brokerage%',
      '%bkrg%',
      '%schwab%',
      '%moneylink%',
      '%invest%'
    ])
  );

GRANT SELECT ON public.spendable_income_transactions TO authenticated;

-- =============================================================================
-- DONE! Database is ready for the iOS app.
-- =============================================================================
