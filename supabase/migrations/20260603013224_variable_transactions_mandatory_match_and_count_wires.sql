-- Two fixes to public.variable_transactions (the discretionary / safe-to-spend layer):
--
-- FIX A — Suppress transactions that match an active mandatory expense stream by
--   merchant, even when is_recurring is still FALSE.
--
--   `is_recurring` is only set TRUE once a transaction has been linked to its stream
--   in recurring_stream_transactions_table (see _shared/recurring.ts). Brand-new
--   *pending* transactions are not linked yet, so a freshly-posted recurring bill
--   (e.g. this month's rent) leaks into variable_transactions until it settles. That
--   double-counts it: once in "Monthly obligations" (it is already in
--   monthly_mandatory_expenses) and again in "What you've spent this month", and it
--   also detonates the daily safe-to-spend number when a $2,650 rent charge lands in
--   a single day's tiny allowance.
--
--   The NOT EXISTS below treats any txn whose merchant matches an active mandatory
--   stream as already-accounted-for (it belongs to the obligations bucket), closing
--   the gap without waiting on Plaid's stream linkage.
--
-- FIX #8 — Count external wire transfers (TRANSFER_OUT_OTHER_TRANSFER_OUT, e.g. the
--   monthly spousal-support wire) as variable spend. Previously these were excluded
--   here, so — being in no recurring stream either — they fell through every layer
--   and surfaced only in the Money-Left "Not counted" section. They are real money out
--   and the user wants them counted. Internal TRANSFER_OUT_ACCOUNT_TRANSFER /
--   TRANSFER_OUT_WITHDRAWAL were already counted and stay counted.

CREATE OR REPLACE VIEW public.variable_transactions
WITH (security_invoker = true)
AS
SELECT t.*
FROM public.transactions t
WHERE t.is_spend
  AND (t.is_recurring = FALSE OR t.is_recurring IS NULL)
  AND NOT EXISTS (
    SELECT 1
    FROM public.active_mandatory_expense_streams ames
    WHERE ames.user_id = t.user_id
      AND (ames.user_marked_recurring = TRUE OR ames.user_marked_recurring IS NULL)
      AND NULLIF(BTRIM(ames.merchant_name), '') IS NOT NULL
      AND LOWER(BTRIM(t.merchant_name)) = LOWER(BTRIM(ames.merchant_name))
  );

GRANT SELECT ON public.variable_transactions TO authenticated;
