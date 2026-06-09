-- Restore "external inflows count as income" — regressed by the 2026-06-06 Pulse migration.
--
-- Background: 20260603090000_count_external_inflows_as_income.sql deliberately DROPPED the
-- name/merchant exclusion from is_income, so ANY INCOME-category inflow into a depository
-- account counts as income (symmetric with external money-out counting as spend). This is the
-- user's standing decision: a brokerage credit like "Manual CR-Bkrg" (which literally funds the
-- monthly spousal wire) is real spendable money in and must offset the real money out.
--
-- Regression: 20260606081820_pulse_total_spend_with_bills_bucket.sql recreated the transactions
-- view to add the additive is_mandatory column, but copied an OLDER (pre-2026-06-03) is_income
-- body — silently re-adding the `%transfer%/%wire%/%brokerage%/%bkrg%/%schwab%/%moneylink%/%invest%`
-- exclusion. Effect: the Damage Report IN (get_daily_transaction_stats.total_in sums is_income)
-- dropped the $6,464 brokerage credit and showed only the $5,495 payroll, while "How we got this"
-- (spendable_income_transactions, which never had the regression) correctly showed the $6,464 as
-- extra income. The two surfaces disagreed.
--
-- Fix: recreate the transactions view from the CURRENT (2026-06-06) definition — keeping is_spend,
-- is_mandatory and the exact column order intact — but with the clean is_income from 2026-06-03
-- (no name/merchant exclusion). Only the is_income expression changes; the column set is identical,
-- so dependent views (variable_transactions, spendable_income_transactions) stay valid and need no
-- redeclaration.

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

  -- Symmetric with is_spend's external money-out: any INCOME-category inflow into a depository
  -- (non-credit / non-loan) account is income, regardless of brokerage/wire/transfer naming.
  -- The name/merchant exclusion is intentionally absent (restored from 2026-06-03).
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
  t.datetime,

  -- Bill / mandatory classification — complement of variable_transactions' exclusion.
  -- Matches a row to an active mandatory expense stream by merchant even before Plaid
  -- links it to a stream (is_recurring still FALSE for fresh pending bills).
  -- MUST stay last: CREATE OR REPLACE VIEW only permits appending new columns.
  (
    t.is_recurring = TRUE
    OR EXISTS (
      SELECT 1
      FROM public.active_mandatory_expense_streams ames
      WHERE ames.user_id = a.user_id
        AND (ames.user_marked_recurring = TRUE OR ames.user_marked_recurring IS NULL)
        AND NULLIF(BTRIM(ames.merchant_name), '') IS NOT NULL
        AND LOWER(BTRIM(t.merchant_name)) = LOWER(BTRIM(ames.merchant_name))
    )
  ) AS is_mandatory

FROM public.transactions_table t
LEFT JOIN public.accounts a ON t.account_id = a.id;

GRANT SELECT ON public.transactions TO authenticated;
