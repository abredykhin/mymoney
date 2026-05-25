-- Centralize "spendable income" classification for budget math.
--
-- The iOS client should not decide which inflows are usable income. Plaid can
-- classify large brokerage movements, wire reversals, and account transfers as
-- negative transactions on depository accounts, and those must not inflate the
-- Home hero's "left to spend" budget.
CREATE OR REPLACE VIEW public.spendable_income_transactions
WITH (security_invoker = true)
AS
SELECT t.*
FROM public.transactions t
WHERE t.amount < 0
  AND COALESCE(t.type, '') NOT IN ('credit', 'loan')
  AND t.personal_finance_category = 'INCOME'
  AND NOT (
    COALESCE(t.name, '') ILIKE ANY (ARRAY[
      '%transfer%',
      '%wire%',
      '%reversal%',
      '%brokerage%',
      '%bkrg%',
      '%schwab%',
      '%moneylink%',
      '%invest%',
      '%healthequity%'
    ])
    OR COALESCE(t.merchant_name, '') ILIKE ANY (ARRAY[
      '%transfer%',
      '%wire%',
      '%reversal%',
      '%brokerage%',
      '%bkrg%',
      '%schwab%',
      '%moneylink%',
      '%invest%',
      '%healthequity%'
    ])
  );

GRANT SELECT ON public.spendable_income_transactions TO authenticated;
