-- Fix variable_transactions view: bake in two filters that were silently
-- required of every iOS caller but absent from the view definition.
--
-- Bug A: TRANSFER_OUT / TRANSFER_IN rows leaked through.
--   personal_finance_category values like 'TRANSFER_OUT' and 'TRANSFER_IN'
--   represent money moving between the user's own accounts (wire transfers,
--   investment contributions, ATM withdrawals, Venmo, etc.).  They are NOT
--   spending and must never appear in a variable-spend calculation.
--   The iOS fetchVariableSpend added NOT ILIKE '%transfer%' every time it
--   called the view — that filter was the only thing preventing $179k of
--   TRANSFER_OUT from inflating May's variable spend.
--
-- Bug B: LOAN_PAYMENTS_CREDIT_CARD_PAYMENT rows leaked through.
--   When a user pays their credit-card bill from a checking account the
--   transaction is categorised as LOAN_PAYMENTS / CREDIT_CARD_PAYMENT.
--   The underlying card charges are already tracked as individual
--   transactions on the credit-card account, so including the payment
--   too double-counts that spending.  In May this inflated variable spend
--   by ~$2,400 (7 transactions) out of a raw total of $2,983 — meaning
--   ~80 % of the reported variable spend was phantom.

CREATE OR REPLACE VIEW variable_transactions AS
SELECT t.*
FROM transactions t
WHERE
  -- Only non-recurring transactions (the original filter)
  (t.is_recurring = FALSE OR t.is_recurring IS NULL)
  -- Bug A: exclude all inter-account transfers
  AND t.personal_finance_category NOT ILIKE '%TRANSFER%'
  -- Bug B: exclude credit-card bill payments (already counted on the card)
  AND t.personal_finance_subcategory != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT';

ALTER VIEW variable_transactions SET (security_invoker = true);
