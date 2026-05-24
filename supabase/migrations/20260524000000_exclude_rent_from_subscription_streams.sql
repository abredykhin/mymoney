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
    'apartment rent',
    'mortgage',
    'mortgage payment'
  )
  AND LOWER(BTRIM(description)) NOT IN (
    'rent',
    'rent payment',
    'apartment rent',
    'mortgage',
    'mortgage payment'
  );

GRANT SELECT ON public.active_subscription_streams TO authenticated;
