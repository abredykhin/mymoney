-- Migration: Fix transaction stats filtering to keep consumer spending categories with "Payment" or "Transfer" in the name
-- Drop existing functions to ensure clean replacement with correct return columns
DROP FUNCTION IF EXISTS public.get_monthly_transaction_stats(date, date);
DROP FUNCTION IF EXISTS public.get_daily_transaction_stats(date, date);

-- 1. Redefine public.get_monthly_transaction_stats
CREATE OR REPLACE FUNCTION public.get_monthly_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (
  year double precision,
  month double precision,
  total_in double precision,
  total_out double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    -- Use authorized_date if available, otherwise fall back to date
    EXTRACT(YEAR FROM COALESCE(t.authorized_date, t.date))::double precision as year,
    EXTRACT(MONTH FROM COALESCE(t.authorized_date, t.date))::double precision as month,
    COALESCE(SUM(
      CASE
        -- Loan: Positive is Advance (In)
        WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
        -- Depository/Investment: Negative is Deposit (In)
        -- This excludes credit cards - payments to credit cards are NOT income
        WHEN (a.type ILIKE 'depository' OR a.type ILIKE 'investment') AND t.amount < 0 THEN ABS(t.amount)
        ELSE 0
      END
    ), 0)::double precision as total_in,
    COALESCE(SUM(
      CASE
        -- Loan: Negative is Payment (Out)
        WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        -- Investment: Exclude positive amounts (Stock buys are NOT spending)
        WHEN a.type ILIKE 'investment' THEN 0
        -- All other accounts (Depository, Credit): Positive is Expense (Out)
        WHEN t.amount > 0 THEN t.amount
        ELSE 0
      END
    ), 0)::double precision as total_out
  FROM
    public.transactions_table t
  JOIN
    public.accounts_table a ON t.account_id = a.id
  WHERE
    t.user_id = auth.uid()
    -- Use authorized_date if available, otherwise fall back to date
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    -- Exclude transfers and credit card payments completely
    AND (
      -- Legitimate spending: category is not transfer, loan payment, or null
      (
        t.personal_finance_category IS NOT NULL 
        AND t.personal_finance_category NOT ILIKE '%TRANSFER%' 
        AND t.personal_finance_category NOT ILIKE 'LOAN_PAYMENTS%'
      )
      OR
      -- Unclassified category: only include if the name doesn't look like a payment/transfer
      (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
    -- Exclude brokerage/transfer/reversal-like transactions even if classified as INCOME
    AND NOT (
      t.personal_finance_category = 'INCOME'
      AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
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
    )
  GROUP BY
    1, 2
  ORDER BY
    1 DESC, 2 DESC;
END;
$$;

-- 2. Redefine public.get_daily_transaction_stats
CREATE OR REPLACE FUNCTION public.get_daily_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (
  date date,
  total_in double precision,
  total_out double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    -- Use authorized_date if available, otherwise fall back to date
    COALESCE(t.authorized_date, t.date) as date,
    COALESCE(SUM(
      CASE
        -- Loan: Positive is Advance (In)
        WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
        -- Depository/Investment: Negative is Deposit (In)
        -- This excludes credit cards - payments to credit cards are NOT income
        WHEN (a.type ILIKE 'depository' OR a.type ILIKE 'investment') AND t.amount < 0 THEN ABS(t.amount)
        ELSE 0
      END
    ), 0)::double precision as total_in,
    COALESCE(SUM(
      CASE
        -- Loan: Negative is Payment (Out)
        WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        -- Investment: Exclude positive amounts (Stock buys are NOT spending)
        WHEN a.type ILIKE 'investment' THEN 0
        -- All other accounts (Depository, Credit): Positive is Expense (Out)
        WHEN t.amount > 0 THEN t.amount
        ELSE 0
      END
    ), 0)::double precision as total_out
  FROM
    public.transactions_table t
  JOIN
    public.accounts_table a ON t.account_id = a.id
  WHERE
    t.user_id = auth.uid()
    -- Use authorized_date if available, otherwise fall back to date
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    -- Exclude transfers and credit card payments completely
    AND (
      -- Legitimate spending: category is not transfer, loan payment, or null
      (
        t.personal_finance_category IS NOT NULL 
        AND t.personal_finance_category NOT ILIKE '%TRANSFER%' 
        AND t.personal_finance_category NOT ILIKE 'LOAN_PAYMENTS%'
      )
      OR
      -- Unclassified category: only include if the name doesn't look like a payment/transfer
      (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
    -- Exclude brokerage/transfer/reversal-like transactions even if classified as INCOME
    AND NOT (
      t.personal_finance_category = 'INCOME'
      AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
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
    )
  GROUP BY
    1
  ORDER BY
    1 DESC;
END;
$$;

-- Security & Permissions
ALTER FUNCTION public.get_monthly_transaction_stats(date, date) SECURITY DEFINER;
REVOKE EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) TO authenticated;

ALTER FUNCTION public.get_daily_transaction_stats(date, date) SECURITY DEFINER;
REVOKE EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) TO authenticated;
