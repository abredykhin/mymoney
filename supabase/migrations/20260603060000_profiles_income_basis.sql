-- T2: Add income_basis column to profiles_table and expose it in the profiles view.
--
-- income_basis controls how pool_total is derived in get_budget_state():
--   'projected' (default) — income-discretionary model:
--                           pool_total = max(0, effectiveIncome - mandatory - goals)
--   'cash_only'           — cash-balance model (Simple-style):
--                           pool_total = max(0, netCash - upcomingBills - goals)

ALTER TABLE public.profiles_table
  ADD COLUMN IF NOT EXISTS income_basis text NOT NULL DEFAULT 'projected'
  CHECK (income_basis IN ('projected', 'cash_only'));

-- Recreate the profiles view to include the new column.
DROP VIEW IF EXISTS public.profiles;

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
    spending_plan_mode,
    time_zone,
    income_basis
  FROM
    public.profiles_table;
