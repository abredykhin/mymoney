-- Refine active_subscription_streams to exclude non-subscription bills
-- Exclude:
-- 1. LOAN_PAYMENTS category (credit card payments, auto loans, etc.)
-- 2. RENT_AND_UTILITIES category (phone bills, electricity, water, internet, etc. - note that rent is already excluded)
-- 3. GENERAL_SERVICES_INSURANCE subcategory (home, car, pet insurance, etc.)
-- 4. GENERAL_SERVICES_AUTOMOTIVE subcategory (automotive leases, etc.)

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
