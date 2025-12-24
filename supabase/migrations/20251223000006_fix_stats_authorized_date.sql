-- Fix transaction statistics functions to use authorized_date with fallback to date
-- This matches the iOS app logic for grouping transactions

-- Function to get monthly transaction stats (UPDATED)
CREATE OR REPLACE FUNCTION get_monthly_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (
  year double precision,
  month double precision,
  total_in numeric,
  total_out numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    -- Use authorized_date if available, otherwise fall back to date
    EXTRACT(YEAR FROM COALESCE(t.authorized_date, t.date)) as year,
    EXTRACT(MONTH FROM COALESCE(t.authorized_date, t.date)) as month,
    SUM(
      CASE
        -- Loan: Positive is Advance (In)
        WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
        -- Standard: Negative is Deposit (In)
        WHEN a.type NOT ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        ELSE 0
      END
    ) as total_in,
    SUM(
      CASE
        -- Loan: Negative is Payment (Out)
        WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        -- Standard: Positive is Expense (Out)
        WHEN a.type NOT ILIKE 'loan' AND t.amount > 0 THEN t.amount
        ELSE 0
      END
    ) as total_out
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

-- Function to get daily transaction stats (UPDATED)
CREATE OR REPLACE FUNCTION get_daily_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (
  date date,
  total_in numeric,
  total_out numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    -- Use authorized_date if available, otherwise fall back to date
    COALESCE(t.authorized_date, t.date) as date,
    SUM(
      CASE
        -- Loan: Positive is Advance (In)
        WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
        -- Standard: Negative is Deposit (In)
        WHEN a.type NOT ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        ELSE 0
      END
    ) as total_in,
    SUM(
      CASE
        -- Loan: Negative is Payment (Out)
        WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        -- Standard: Positive is Expense (Out)
        WHEN a.type NOT ILIKE 'loan' AND t.amount > 0 THEN t.amount
        ELSE 0
      END
    ) as total_out
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
