-- Exclude TRANSFER_OUT_OTHER_TRANSFER_OUT (wire transfers) from variable_transactions.
--
-- Wire transfers are real money-out and correctly appear in the damage report via
-- is_spend = true. But they are not discretionary variable spending and must not
-- inflate the liquid hero budget widget.
--
-- TRANSFER_OUT_ACCOUNT_TRANSFER (therapy, Venmo) and TRANSFER_OUT_WITHDRAWAL (ATM)
-- remain in variable_transactions since they ARE discretionary person-level spending.

CREATE OR REPLACE VIEW public.variable_transactions
WITH (security_invoker = true)
AS
SELECT t.*
FROM public.transactions t
WHERE t.is_spend
  AND (t.is_recurring = FALSE OR t.is_recurring IS NULL)
  AND COALESCE(t.personal_finance_subcategory, '') != 'TRANSFER_OUT_OTHER_TRANSFER_OUT';
