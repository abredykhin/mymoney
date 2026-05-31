-- Redefine public.transactions to always exclude credit card payments from spending,
-- regardless of whether the destination card is linked or unlinked in the app.

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
            '%bkrg%', '%schwab%', '%moneylink%', '%invest%'
          ])
        )
      )
    )
  ) AS is_income

FROM public.transactions_table t
LEFT JOIN public.accounts a ON t.account_id = a.id;

GRANT SELECT ON public.transactions TO authenticated;
