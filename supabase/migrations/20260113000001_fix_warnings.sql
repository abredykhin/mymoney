-- Fix mutable search_path warnings and optimize RLS
-- Date: 2026-01-13
-- Addresses Supabase Warnings for mutable search_path and suboptimal RLS policies

-- 1. Fix mutable search_path for generic timestamp trigger
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- 2. Fix mutable search_path for auth handler
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles_table (id, username)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Fix mutable search_path for Transaction Stats (Monthly)
-- Drop first to avoid return type conflict (numeric vs double precision)
DROP FUNCTION IF EXISTS get_monthly_transaction_stats(date, date);

CREATE OR REPLACE FUNCTION get_monthly_transaction_stats(
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
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    EXTRACT(YEAR FROM COALESCE(t.authorized_date, t.date))::double precision as year,
    EXTRACT(MONTH FROM COALESCE(t.authorized_date, t.date))::double precision as month,
    COALESCE(SUM(
      CASE
        -- Loan: Positive is Advance (In)
        WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
        -- Standard: Negative is Deposit (In)
        WHEN a.type NOT ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        ELSE 0
      END
    ), 0)::double precision as total_in,
    COALESCE(SUM(
      CASE
        -- Loan: Negative is Payment (Out)
        WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        -- Standard: Positive is Expense (Out)
        WHEN a.type NOT ILIKE 'loan' AND t.amount > 0 THEN t.amount
        ELSE 0
      END
    ), 0)::double precision as total_out
  FROM
    transactions_table t
  JOIN
    accounts_table a ON t.account_id = a.id
  WHERE
    t.user_id = auth.uid()
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    AND (t.name NOT ILIKE '%Payment%' AND t.name NOT ILIKE '%Transfer%')
  GROUP BY
    1, 2
  ORDER BY
    1 DESC, 2 DESC;
END;
$$;

-- 4. Fix mutable search_path for Transaction Stats (Daily)
-- Drop first to avoid return type conflict
DROP FUNCTION IF EXISTS get_daily_transaction_stats(date, date);

CREATE OR REPLACE FUNCTION get_daily_transaction_stats(
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
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(t.authorized_date, t.date) as date,
    COALESCE(SUM(
      CASE
        -- Loan: Positive is Advance (In)
        WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
        -- Standard: Negative is Deposit (In)
        WHEN a.type NOT ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        ELSE 0
      END
    ), 0)::double precision as total_in,
    COALESCE(SUM(
      CASE
        -- Loan: Negative is Payment (Out)
        WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        -- Standard: Positive is Expense (Out)
        WHEN a.type NOT ILIKE 'loan' AND t.amount > 0 THEN t.amount
        ELSE 0
      END
    ), 0)::double precision as total_out
  FROM
    transactions_table t
  JOIN
    accounts_table a ON t.account_id = a.id
  WHERE
    t.user_id = auth.uid()
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    AND (t.name NOT ILIKE '%Payment%' AND t.name NOT ILIKE '%Transfer%')
  GROUP BY
    1
  ORDER BY
    1 DESC;
END;
$$;

-- 5. Optimize RLS Policies
-- Replace direct calls to auth.uid() with (select auth.uid()) to allow caching/performance optimization

-- Users can view their own profile
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles_table;
CREATE POLICY "Users can view their own profile" ON profiles_table FOR SELECT USING ((select auth.uid()) = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles_table;
CREATE POLICY "Users can update their own profile" ON profiles_table FOR UPDATE USING ((select auth.uid()) = id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles_table;
CREATE POLICY "Users can insert their own profile" ON profiles_table FOR INSERT WITH CHECK ((select auth.uid()) = id);

-- Items
DROP POLICY IF EXISTS "Users can view their own items" ON items_table;
CREATE POLICY "Users can view their own items" ON items_table FOR SELECT USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own items" ON items_table;
CREATE POLICY "Users can insert their own items" ON items_table FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own items" ON items_table;
CREATE POLICY "Users can update their own items" ON items_table FOR UPDATE USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete their own items" ON items_table;
CREATE POLICY "Users can delete their own items" ON items_table FOR DELETE USING ((select auth.uid()) = user_id);

-- Assets
DROP POLICY IF EXISTS "Users can view their own assets" ON assets_table;
CREATE POLICY "Users can view their own assets" ON assets_table FOR SELECT USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own assets" ON assets_table;
CREATE POLICY "Users can insert their own assets" ON assets_table FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own assets" ON assets_table;
CREATE POLICY "Users can update their own assets" ON assets_table FOR UPDATE USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete their own assets" ON assets_table;
CREATE POLICY "Users can delete their own assets" ON assets_table FOR DELETE USING ((select auth.uid()) = user_id);

-- Accounts
DROP POLICY IF EXISTS "Users can view their own accounts" ON accounts_table;
CREATE POLICY "Users can view their own accounts" ON accounts_table FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM items_table
      WHERE items_table.id = accounts_table.item_id
      AND items_table.user_id = (select auth.uid())
    )
);

DROP POLICY IF EXISTS "Users can insert their own accounts" ON accounts_table;
CREATE POLICY "Users can insert their own accounts" ON accounts_table FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM items_table
      WHERE items_table.id = accounts_table.item_id
      AND items_table.user_id = (select auth.uid())
    )
);

DROP POLICY IF EXISTS "Users can update their own accounts" ON accounts_table;
CREATE POLICY "Users can update their own accounts" ON accounts_table FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM items_table
      WHERE items_table.id = accounts_table.item_id
      AND items_table.user_id = (select auth.uid())
    )
);

DROP POLICY IF EXISTS "Users can delete their own accounts" ON accounts_table;
CREATE POLICY "Users can delete their own accounts" ON accounts_table FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM items_table
      WHERE items_table.id = accounts_table.item_id
      AND items_table.user_id = (select auth.uid())
    )
);

-- Transactions
DROP POLICY IF EXISTS "Users can view their own transactions" ON transactions_table;
CREATE POLICY "Users can view their own transactions" ON transactions_table FOR SELECT USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own transactions" ON transactions_table;
CREATE POLICY "Users can insert their own transactions" ON transactions_table FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own transactions" ON transactions_table;
CREATE POLICY "Users can update their own transactions" ON transactions_table FOR UPDATE USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete their own transactions" ON transactions_table;
CREATE POLICY "Users can delete their own transactions" ON transactions_table FOR DELETE USING ((select auth.uid()) = user_id);

-- Refresh Jobs
DROP POLICY IF EXISTS "Users can view their own refresh jobs" ON refresh_jobs;
CREATE POLICY "Users can view their own refresh jobs" ON refresh_jobs FOR SELECT USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own refresh jobs" ON refresh_jobs;
CREATE POLICY "Users can insert their own refresh jobs" ON refresh_jobs FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own refresh jobs" ON refresh_jobs;
CREATE POLICY "Users can update their own refresh jobs" ON refresh_jobs FOR UPDATE USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete their own refresh jobs" ON refresh_jobs;
CREATE POLICY "Users can delete their own refresh jobs" ON refresh_jobs FOR DELETE USING ((select auth.uid()) = user_id);

-- Link Events
DROP POLICY IF EXISTS "Users can view their own link events" ON link_events_table;
CREATE POLICY "Users can view their own link events" ON link_events_table FOR SELECT USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own link events" ON link_events_table;
CREATE POLICY "Users can insert their own link events" ON link_events_table FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

-- Plaid API Events
DROP POLICY IF EXISTS "Users can view their own API events" ON plaid_api_events_table;
CREATE POLICY "Users can view their own API events" ON plaid_api_events_table FOR SELECT USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own API events" ON plaid_api_events_table;
CREATE POLICY "Users can insert their own API events" ON plaid_api_events_table FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

-- Budget Items
DROP POLICY IF EXISTS "Users can view their own budget items" ON budget_items_table;
CREATE POLICY "Users can view their own budget items" ON budget_items_table FOR SELECT USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own budget items" ON budget_items_table;
CREATE POLICY "Users can insert their own budget items" ON budget_items_table FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own budget items" ON budget_items_table;
CREATE POLICY "Users can update their own budget items" ON budget_items_table FOR UPDATE USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete their own budget items" ON budget_items_table;
CREATE POLICY "Users can delete their own budget items" ON budget_items_table FOR DELETE USING ((select auth.uid()) = user_id);
