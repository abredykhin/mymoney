-- Migration to add transaction statistics functions
-- These functions allow the client to fetch correct totals even when data is paginated

-- Function to get monthly transaction stats
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
    EXTRACT(YEAR FROM t.date) as year,
    EXTRACT(MONTH FROM t.date) as month,
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
    AND t.date BETWEEN start_date AND end_date
    -- Exclude transfers logic (matching Swift implementation best effort)
    AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    AND (t.name NOT ILIKE '%Payment%' AND t.name NOT ILIKE '%Transfer%')
  GROUP BY
    1, 2
  ORDER BY
    1 DESC, 2 DESC;
END;
$$;

-- Function to get daily transaction stats
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
    t.date,
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
    AND t.date BETWEEN start_date AND end_date
    -- Exclude transfers logic
    AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    AND (t.name NOT ILIKE '%Payment%' AND t.name NOT ILIKE '%Transfer%')
  GROUP BY
    1
  ORDER BY
    1 DESC;
END;
$$;
