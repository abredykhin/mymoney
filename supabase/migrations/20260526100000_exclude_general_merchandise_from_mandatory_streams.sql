-- GENERAL_MERCHANDISE streams (e.g. Amazon) are retail purchases, not fixed
-- mandatory expenses. Plaid detects them as "recurring" because the merchant
-- appears frequently, but each transaction is variable spending and should show
-- up in the variable spend breakdown, not silently vanish from both buckets.
--
-- Three-part fix:
--   1. Drop GENERAL_MERCHANDISE from active_mandatory_expense_streams view
--   2. Clear is_recurring=true on transactions linked to those streams so they
--      flow through variable_transactions again
--   3. Recompute profile monthly_mandatory_expenses to drop the removed streams

-- ─── 1. Update active_mandatory_expense_streams view ─────────────────────────

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
  AND COALESCE(rs.personal_finance_category, '') <> 'GENERAL_MERCHANDISE'
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

-- ─── 2. Backfill: clear is_recurring on GENERAL_MERCHANDISE stream transactions

UPDATE public.transactions_table t
SET is_recurring = false
FROM public.recurring_stream_transactions_table rst
JOIN public.recurring_streams_table rs ON rs.id = rst.stream_id
WHERE rst.transaction_id = t.id
  AND rs.personal_finance_category = 'GENERAL_MERCHANDISE'
  AND rs.type = 'expense';

-- ─── 3. Recompute profile mandatory expenses for all affected users ───────────
--
-- Only touches profiles where at least one GENERAL_MERCHANDISE expense stream
-- exists, so users with no Amazon-like streams are not updated unnecessarily.

UPDATE public.profiles_table p
SET
  monthly_mandatory_expenses = (
    SELECT COALESCE(SUM(ames.monthly_amount), 0)
    FROM public.active_mandatory_expense_streams ames
    WHERE ames.user_id = p.id
      AND (ames.user_marked_recurring = true OR ames.user_marked_recurring IS NULL)
  ),
  updated_at = now()
WHERE EXISTS (
  SELECT 1
  FROM public.recurring_streams_table rs
  WHERE rs.user_id = p.id
    AND rs.personal_finance_category = 'GENERAL_MERCHANDISE'
    AND rs.type = 'expense'
    AND rs.is_active = true
);
