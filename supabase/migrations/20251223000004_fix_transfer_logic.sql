-- Migration to refine transfer detection logic in stats functions
-- Replaces existing functions with expanded keyword list

-- Update monthly stats function
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
    -- Exclude transfers: check category AND expanded keywords in name
    AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    AND NOT (
        t.name ILIKE '%PAYMENT%' OR
        t.name ILIKE '%TRANSFER%' OR 
        t.name ILIKE '%CREDIT CARD%' OR
        t.name ILIKE '%AUTOPAY%' OR 
        t.name ILIKE '%PMT%' OR
        t.name ILIKE '%DIRECT DEBIT%' OR
        t.name ILIKE '%BILL PAY%'
    )
  GROUP BY
    1, 2
  ORDER BY
    1 DESC, 2 DESC;
END;
$$;

-- Update daily stats function
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
    AND NOT (
        t.name ILIKE '%PAYMENT%' OR
        t.name ILIKE '%TRANSFER%' OR 
        t.name ILIKE '%CREDIT CARD%' OR
        t.name ILIKE '%AUTOPAY%' OR 
        t.name ILIKE '%PMT%' OR
        t.name ILIKE '%DIRECT DEBIT%' OR
        t.name ILIKE '%BILL PAY%'
    )
  GROUP BY
    1
  ORDER BY
    1 DESC;
END;
$$;
