-- Migration to implement robust Account Type based logic
-- Replaces fragile keyword matching with Plaid's definitive In/Out rules

-- Logic:
-- 1. DEPOSITORY/INVESTMENT:
--    - Negative (-) = Money In = INCOME
--    - Positive (+) = Money Out = EXPENSE
-- 2. CREDIT/LOAN:
--    - Negative (-) = Money In = TRANSFER (Payment/Refund) -> IGNORE in Totals
--    - Positive (+) = Money Out = EXPENSE (Purchase/Spend)

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
        -- Income: Only count 'Money In' (Negative) for Asset accounts (Depository/Investment)
        WHEN t.amount < 0 AND (a.type = 'depository' OR a.type = 'investment') THEN ABS(t.amount)
        ELSE 0
      END
    ) as total_in,
    SUM(
      CASE
        -- Expense: Count 'Money Out' (Positive) for ALL accounts (Spending + Transfers Out)
        WHEN t.amount > 0 THEN t.amount
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
    -- Still exclude explicit transfers defined by Category
    AND (
      t.personal_finance_category IS NULL 
      OR t.personal_finance_category NOT ILIKE '%TRANSFER%'
    )
    -- Intentionally REMOVED fragile name-based keyword blocking
  GROUP BY
    1, 2
  ORDER BY
    1 DESC, 2 DESC;
END;
$$;

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
        -- Income: Only count 'Money In' (Negative) for Asset accounts (Depository/Investment)
        WHEN t.amount < 0 AND (a.type = 'depository' OR a.type = 'investment') THEN ABS(t.amount)
        ELSE 0
      END
    ) as total_in,
    SUM(
      CASE
        -- Expense: Count 'Money Out' (Positive) for ALL accounts (Spending + Transfers Out)
        WHEN t.amount > 0 THEN t.amount
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
    -- Still exclude explicit transfers defined by Category
    AND (
      t.personal_finance_category IS NULL 
      OR t.personal_finance_category NOT ILIKE '%TRANSFER%'
    )
  GROUP BY
    1
  ORDER BY
    1 DESC;
END;
$$;
