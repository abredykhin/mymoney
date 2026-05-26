-- Add is_spend and is_income computed boolean columns to the transactions view.
--
-- is_spend = true  →  amount > 0, not from investment account, passes the
--                     category/subcategory allowlist (same rules as all existing
--                     RPCs, now defined once here rather than copy-pasted).
--
-- is_income = true →  amount < 0, not from a credit/loan account, is actual
--                     received money: INCOME category (not brokerage-like) OR
--                     TRANSFER_IN_ACCOUNT_TRANSFER (wire reversal netting).
--
-- All downstream views / functions will reference these flags instead of
-- repeating the filter logic.

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

  -- is_spend: real outgoing spending (not noise/transfers/investment moves)
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
        AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
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
            '%bkrg%', '%schwab%', '%moneylink%', '%invest%', '%healthequity%'
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

  -- is_income: real inbound money (salary/freelance or wire reversal)
  (
    t.amount < 0
    AND COALESCE(a.type, '') NOT ILIKE 'credit'
    AND COALESCE(a.type, '') NOT ILIKE 'loan'
    AND (
      t.personal_finance_subcategory = 'TRANSFER_IN_ACCOUNT_TRANSFER'
      OR (
        t.personal_finance_category = 'INCOME'
        AND NOT (
          COALESCE(t.name, '') ILIKE ANY (ARRAY[
            '%transfer%', '%wire%', '%reversal%', '%brokerage%',
            '%bkrg%', '%schwab%', '%moneylink%', '%invest%', '%healthequity%'
          ])
        )
      )
    )
  ) AS is_income

FROM public.transactions_table t
LEFT JOIN public.accounts a ON t.account_id = a.id;
