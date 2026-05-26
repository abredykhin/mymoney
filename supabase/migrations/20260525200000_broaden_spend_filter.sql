-- Broaden spend filter: only exclude TRANSFER_IN and LOAN_PAYMENTS_CREDIT_CARD_PAYMENT.
--
-- Previously all TRANSFER_OUT and LOAN_PAYMENTS rows were excluded. This was too broad:
-- therapy payments, ATM withdrawals, investment contributions, auto lease, and wire
-- transfers are all real spending but were invisible in every stats surface.
--
-- New rule (applied consistently across all 6 SQL objects below):
--   EXCLUDE: personal_finance_category = 'TRANSFER_IN'     (money coming in, not spending)
--   EXCLUDE: personal_finance_subcategory = 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'  (double-counts card charges)
--   INCLUDE: everything else (all TRANSFER_OUT subcategories, car payments, etc.)
--
-- NULL-category rows keep their existing name-based fallback where applicable.

-- ─── 1. get_daily_transaction_stats ───────────────────────────────────────────

DROP FUNCTION IF EXISTS public.get_daily_transaction_stats(date, date);

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
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(t.authorized_date, t.date) as date,
    COALESCE(SUM(
      CASE
        WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
        WHEN (a.type ILIKE 'depository' OR a.type ILIKE 'investment') AND t.amount < 0 THEN ABS(t.amount)
        ELSE 0
      END
    ), 0)::double precision as total_in,
    COALESCE(SUM(
      CASE
        WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        WHEN a.type ILIKE 'investment' THEN 0
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
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    AND (
      -- Categorized: exclude only TRANSFER_IN and credit card payments
      (
        t.personal_finance_category IS NOT NULL
        AND t.personal_finance_category != 'TRANSFER_IN'
        AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
      )
      OR
      -- NULL category: exclude only if name looks like a payment or transfer
      (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
    -- Exclude brokerage/reversal-like rows even when Plaid tags them as INCOME
    AND NOT (
      t.personal_finance_category = 'INCOME'
      AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
        '%transfer%', '%wire%', '%reversal%', '%brokerage%',
        '%bkrg%', '%schwab%', '%moneylink%', '%invest%', '%healthequity%'
      ])
    )
  GROUP BY
    1
  ORDER BY
    1 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) TO authenticated;

-- ─── 2. get_monthly_transaction_stats ─────────────────────────────────────────

DROP FUNCTION IF EXISTS public.get_monthly_transaction_stats(date, date);

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
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    EXTRACT(YEAR FROM COALESCE(t.authorized_date, t.date))::double precision as year,
    EXTRACT(MONTH FROM COALESCE(t.authorized_date, t.date))::double precision as month,
    COALESCE(SUM(
      CASE
        WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
        WHEN (a.type ILIKE 'depository' OR a.type ILIKE 'investment') AND t.amount < 0 THEN ABS(t.amount)
        ELSE 0
      END
    ), 0)::double precision as total_in,
    COALESCE(SUM(
      CASE
        WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        WHEN a.type ILIKE 'investment' THEN 0
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
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    AND (
      (
        t.personal_finance_category IS NOT NULL
        AND t.personal_finance_category != 'TRANSFER_IN'
        AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
      )
      OR
      (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
    AND NOT (
      t.personal_finance_category = 'INCOME'
      AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
        '%transfer%', '%wire%', '%reversal%', '%brokerage%',
        '%bkrg%', '%schwab%', '%moneylink%', '%invest%', '%healthequity%'
      ])
    )
  GROUP BY
    1, 2
  ORDER BY
    1 DESC, 2 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) TO authenticated;

-- ─── 3. variable_transactions view ────────────────────────────────────────────

CREATE OR REPLACE VIEW variable_transactions AS
SELECT t.*
FROM transactions t
WHERE
  (t.is_recurring = FALSE OR t.is_recurring IS NULL)
  AND t.personal_finance_category != 'TRANSFER_IN'
  AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT';

ALTER VIEW variable_transactions SET (security_invoker = true);

-- ─── 4. get_user_spending_streak ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_user_spending_streak()
RETURNS TABLE (
    current_streak INT,
    max_streak INT,
    last_10_days_status BOOLEAN[]
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    income_val NUMERIC(28,2);
    actual_income NUMERIC(28,2);
    fixed_exp NUMERIC(28,2);
    daily_limit NUMERIC(28,2);
    streak_count INT := 0;
    max_streak_count INT := 0;
    temp_streak INT := 0;
    day_idx INT;
    spend_on_day NUMERIC(28,2);
    status_arr BOOLEAN[] := '{}';
    day_date DATE;
    current_streak_set BOOLEAN := FALSE;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.items_table
        WHERE user_id = (SELECT auth.uid())
          AND is_active = TRUE
    ) THEN
        RETURN;
    END IF;

    SELECT COALESCE(monthly_income, 0), COALESCE(monthly_mandatory_expenses, 0)
    INTO income_val, fixed_exp
    FROM public.profiles_table
    WHERE id = (SELECT auth.uid());

    SELECT COALESCE(SUM(ABS(amount)), 0)
    INTO actual_income
    FROM public.spendable_income_transactions
    WHERE user_id = (SELECT auth.uid())
      AND date >= DATE_TRUNC('month', CURRENT_DATE)::DATE
      AND date <= (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    income_val := GREATEST(income_val, actual_income);

    daily_limit := (income_val - fixed_exp) / 30.0;
    IF daily_limit <= 0 THEN
        daily_limit := 50.00;
    END IF;

    FOR day_idx IN 0..89 LOOP
        day_date := CURRENT_DATE - day_idx;

        SELECT COALESCE(SUM(amount), 0)
        INTO spend_on_day
        FROM public.transactions_table
        WHERE user_id = (SELECT auth.uid())
          AND COALESCE(authorized_date, date) = day_date
          AND amount > 0
          AND (personal_finance_category IS NULL OR personal_finance_category != 'TRANSFER_IN')
          AND COALESCE(personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT';

        IF spend_on_day <= daily_limit THEN
            temp_streak := temp_streak + 1;
            IF day_idx < 10 THEN
                status_arr := array_append(status_arr, TRUE);
            END IF;
        ELSE
            IF NOT current_streak_set THEN
                streak_count := temp_streak;
                current_streak_set := TRUE;
            END IF;

            IF temp_streak > max_streak_count THEN
                max_streak_count := temp_streak;
            END IF;

            temp_streak := 0;
            IF day_idx < 10 THEN
                status_arr := array_append(status_arr, FALSE);
            END IF;
        END IF;
    END LOOP;

    IF NOT current_streak_set THEN
        streak_count := temp_streak;
    END IF;

    IF temp_streak > max_streak_count THEN
        max_streak_count := temp_streak;
    END IF;

    RETURN QUERY SELECT streak_count, max_streak_count, status_arr;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_user_spending_streak() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_spending_streak() TO authenticated;

-- ─── 5. get_pulse_weekly_energy ───────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.get_pulse_weekly_energy(date, date);

CREATE OR REPLACE FUNCTION public.get_pulse_weekly_energy(
    week_start DATE,
    week_end DATE
)
RETURNS TABLE (
    weekday TEXT,
    date_label DATE,
    total_spent DOUBLE PRECISION,
    is_peak BOOLEAN,
    peak_merchant TEXT,
    peak_category TEXT,
    peak_amount DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    peak_date DATE;
BEGIN
    SELECT COALESCE(t.authorized_date, t.date) INTO peak_date
    FROM public.transactions_table t
    WHERE t.user_id = auth.uid()
      AND COALESCE(t.authorized_date, t.date) BETWEEN week_start AND week_end
      AND t.amount > 0
      AND (t.personal_finance_category IS NULL OR t.personal_finance_category != 'TRANSFER_IN')
      AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
    GROUP BY COALESCE(t.authorized_date, t.date)
    ORDER BY SUM(t.amount) DESC
    LIMIT 1;

    RETURN QUERY
    WITH daily_totals AS (
        SELECT
            COALESCE(t.authorized_date, t.date) as t_date,
            SUM(t.amount)::double precision as t_sum
        FROM public.transactions_table t
        WHERE t.user_id = auth.uid()
          AND COALESCE(t.authorized_date, t.date) BETWEEN week_start AND week_end
          AND t.amount > 0
          AND (t.personal_finance_category IS NULL OR t.personal_finance_category != 'TRANSFER_IN')
          AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
        GROUP BY COALESCE(t.authorized_date, t.date)
    ),
    peak_transactions AS (
        SELECT DISTINCT ON (COALESCE(t.authorized_date, t.date))
            COALESCE(t.authorized_date, t.date) as t_date,
            COALESCE(t.merchant_name, t.name) as merchant,
            t.personal_finance_category as category,
            t.amount::double precision as amount
        FROM public.transactions_table t
        WHERE t.user_id = auth.uid()
          AND COALESCE(t.authorized_date, t.date) BETWEEN week_start AND week_end
          AND t.amount > 0
        ORDER BY COALESCE(t.authorized_date, t.date), t.amount DESC
    )
    SELECT
        TO_CHAR(d.date_series, 'Dy') as weekday,
        d.date_series::date as date_label,
        COALESCE(dt.t_sum, 0.0)::double precision as total_spent,
        (d.date_series::date = peak_date) as is_peak,
        COALESCE(pt.merchant, 'No Spend') as peak_merchant,
        pt.category as peak_category,
        COALESCE(pt.amount, 0.0)::double precision as peak_amount
    FROM
        GENERATE_SERIES(week_start::timestamp, week_end::timestamp, '1 day'::interval) d(date_series)
    LEFT JOIN daily_totals dt ON dt.t_date = d.date_series::date
    LEFT JOIN peak_transactions pt ON pt.t_date = d.date_series::date
    ORDER BY d.date_series ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) TO authenticated;

-- ─── 6. get_pulse_top_merchants ───────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.get_pulse_top_merchants(date, date, integer);

CREATE OR REPLACE FUNCTION public.get_pulse_top_merchants(
    start_date DATE,
    end_date DATE,
    lim INTEGER DEFAULT 5
)
RETURNS TABLE (
    merchant_name TEXT,
    total_spent DOUBLE PRECISION,
    transaction_count BIGINT,
    personal_finance_category TEXT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(t.merchant_name, t.name) as merchant_name,
        SUM(t.amount)::double precision as total_spent,
        COUNT(*)::bigint as transaction_count,
        MIN(t.personal_finance_category) as personal_finance_category
    FROM
        public.transactions_table t
    WHERE
        t.user_id = auth.uid()
        AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
        AND t.amount > 0
        AND (t.personal_finance_category IS NULL OR t.personal_finance_category != 'TRANSFER_IN')
        AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
    GROUP BY
        COALESCE(t.merchant_name, t.name)
    ORDER BY
        total_spent DESC
    LIMIT
        lim;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) TO authenticated;
