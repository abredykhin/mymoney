-- Centralize mandatory recurring expense selection for profile budget totals.
--
-- Manual onboarding rent can coexist with Plaid-detected rent after account
-- linking. When both exist, keep the Plaid stream and suppress the manual rent
-- placeholder so mandatory expenses are not double-counted.
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
