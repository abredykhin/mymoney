-- Fix spending stats to exclude investment purchases
-- Investment "buys" should not be counted as monthly spending

-- Drop existing functions to ensure clean replacement
DROP FUNCTION IF EXISTS get_monthly_transaction_stats(date, date);
DROP FUNCTION IF EXISTS get_daily_transaction_stats(date, date);

-- Function to get monthly transaction stats (UPDATED - Exclude Investment spending)
CREATE FUNCTION get_monthly_transaction_stats(
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
    transactions_table t
  JOIN
    accounts_table a ON t.account_id = a.id
  WHERE
    t.user_id = auth.uid()
    -- Use authorized_date if available, otherwise fall back to date
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    -- Exclude transfers logic (matching Swift implementation best effort)
    AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    AND (t.name NOT ILIKE '%Payment%' AND t.name NOT ILIKE '%Transfer%')
  GROUP BY
    1, 2
  ORDER BY
    1 DESC, 2 DESC;
END;
$$;

-- Function to get daily transaction stats (UPDATED - Exclude Investment spending)
CREATE FUNCTION get_daily_transaction_stats(
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
    transactions_table t
  JOIN
    accounts_table a ON t.account_id = a.id
  WHERE
    t.user_id = auth.uid()
    -- Use authorized_date if available, otherwise fall back to date
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    -- Exclude transfers logic
    AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    AND (t.name NOT ILIKE '%Payment%' AND t.name NOT ILIKE '%Transfer%')
  GROUP BY
    1
  ORDER BY
    1 DESC;
END;
$$;
