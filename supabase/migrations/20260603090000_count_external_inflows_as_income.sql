-- Count external inflows as income — symmetric with counting external money-out as spend.
--
-- Background: external money OUT already counts as spend. variable_transactions /
-- is_spend include TRANSFER_OUT_OTHER_TRANSFER_OUT (e.g. the monthly spousal-support
-- wire), TRANSFER_OUT_ACCOUNT_TRANSFER and TRANSFER_OUT_WITHDRAWAL. But the mirror —
-- external money IN — was being stripped: is_income and spendable_income_transactions
-- both excluded INCOME-category inflows whose name/merchant matched
-- transfer/wire/reversal/brokerage/bkrg/schwab/moneylink/invest. That left brokerage
-- credits (e.g. "Manual CR-Bkrg", which in this user's case literally fund the spousal
-- wire) counted nowhere: the wire depleted the discretionary pool while the matching
-- inflow that funded it never replenished it.
--
-- Decision (user, 2026-06-03): treat ANY INCOME-category inflow into a depository
-- (non-credit / non-loan) account as income — drop the name/merchant exclusion entirely.
-- It's not "real" earned income, but it is real spendable money in, and it must offset
-- the real money out. Non-recurring inflows land as "extra" income on top of projected
-- salary (pool grows by the inflow), which is the intended behavior.
--
-- Only the is_income expression of public.transactions and the WHERE of
-- public.spendable_income_transactions change. All columns are kept identical so the
-- dependent views (variable_transactions, spendable_income_transactions) stay valid;
-- variable_transactions is intentionally left at its 20260603013224 definition.

CREATE OR REPLACE VIEW public.transactions
WITH (security_invoker = true)
AS
SELECT
  t.id,
  t.account_id,
  a.user_id,
  a.plaid_account_id,
  a.item_id,
  a.plaid_item_id,
  a.type,
  t.amount,
  t.is_recurring,
  t.iso_currency_code,
  t.date,
  t.authorized_date,
  t.name,
  t.merchant_name,
  t.logo_url,
  t.website,
  t.payment_channel,
  t.transaction_id,
  t.personal_finance_category,
  t.personal_finance_subcategory,
  t.pending,
  t.pending_transaction_transaction_id,
  t.created_at,
  t.updated_at,
  t.spend_date,

  (
    t.amount > 0
    AND COALESCE(a.type, '') NOT ILIKE 'investment'
    AND (
      (
        t.personal_finance_category IS NOT NULL
        AND NOT (
          t.personal_finance_category = 'TRANSFER_IN'
          AND COALESCE(t.personal_finance_subcategory, '') != 'TRANSFER_IN_ACCOUNT_TRANSFER'
        )
        AND NOT (
          COALESCE(t.personal_finance_subcategory, '') = 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
        )
        AND NOT (
          t.personal_finance_category = 'TRANSFER_OUT'
          AND COALESCE(t.personal_finance_subcategory, '') NOT IN (
            'TRANSFER_OUT_ACCOUNT_TRANSFER',
            'TRANSFER_OUT_WITHDRAWAL',
            'TRANSFER_OUT_OTHER_TRANSFER_OUT'
          )
        )
        AND NOT (
          t.personal_finance_category = 'INCOME'
          AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
            '%transfer%', '%wire%', '%reversal%', '%brokerage%',
            '%bkrg%', '%schwab%', '%moneylink%', '%invest%'
          ])
        )
      )
      OR (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
  ) AS is_spend,

  -- Symmetric with is_spend's external money-out: any INCOME-category inflow into a
  -- depository account is income, regardless of brokerage/wire/transfer naming. The
  -- name/merchant exclusion that used to strip brokerage credits has been removed.
  (
    t.amount < 0
    AND COALESCE(a.type, '') NOT ILIKE 'credit'
    AND COALESCE(a.type, '') NOT ILIKE 'loan'
    AND (
      t.personal_finance_subcategory = 'TRANSFER_IN_ACCOUNT_TRANSFER'
      OR t.personal_finance_category = 'INCOME'
    )
  ) AS is_income,

  t.authorized_datetime,
  t.datetime

FROM public.transactions_table t
LEFT JOIN public.accounts a ON t.account_id = a.id;

CREATE OR REPLACE VIEW public.spendable_income_transactions
WITH (security_invoker = true)
AS
SELECT t.*
FROM public.transactions t
WHERE t.amount < 0
  AND COALESCE(t.type, '') NOT IN ('credit', 'loan')
  AND t.personal_finance_category = 'INCOME';

GRANT SELECT ON public.transactions TO authenticated;
GRANT SELECT ON public.spendable_income_transactions TO authenticated;
