-- Store the casual first name collected during onboarding.

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
    first_name
  FROM
    public.profiles_table;
