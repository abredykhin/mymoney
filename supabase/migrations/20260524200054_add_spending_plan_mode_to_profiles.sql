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
