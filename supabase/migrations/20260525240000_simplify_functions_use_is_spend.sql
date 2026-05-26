-- Simplify all views and functions to use is_spend / is_income from the
-- transactions view instead of repeating the filter rules everywhere.

-- variable_transactions: non-recurring spending only (drives liquid hero widget)
CREATE OR REPLACE VIEW public.variable_transactions
WITH (security_invoker = true)
AS
SELECT t.*
FROM public.transactions t
WHERE t.is_spend
  AND (t.is_recurring = FALSE OR t.is_recurring IS NULL);

-- get_daily_transaction_stats
DROP FUNCTION IF EXISTS public.get_daily_transaction_stats(date, date);
CREATE OR REPLACE FUNCTION public.get_daily_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (date date, total_in double precision, total_out double precision)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.spend_date::date AS date,
    COALESCE(SUM(CASE
      WHEN t.is_income THEN ABS(t.amount)
      ELSE 0
    END), 0)::double precision AS total_in,
    COALESCE(SUM(CASE
      WHEN t.is_spend THEN t.amount
      ELSE 0
    END), 0)::double precision AS total_out
  FROM public.transactions t
  WHERE t.user_id = auth.uid()
    AND t.spend_date BETWEEN start_date AND end_date
    AND (t.is_spend OR t.is_income)
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) TO authenticated;

-- get_monthly_transaction_stats
DROP FUNCTION IF EXISTS public.get_monthly_transaction_stats(date, date);
CREATE OR REPLACE FUNCTION public.get_monthly_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (year double precision, month double precision, total_in double precision, total_out double precision)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    EXTRACT(YEAR FROM t.spend_date)::double precision,
    EXTRACT(MONTH FROM t.spend_date)::double precision,
    COALESCE(SUM(CASE WHEN t.is_income THEN ABS(t.amount) ELSE 0 END), 0)::double precision,
    COALESCE(SUM(CASE WHEN t.is_spend  THEN t.amount       ELSE 0 END), 0)::double precision
  FROM public.transactions t
  WHERE t.user_id = auth.uid()
    AND t.spend_date BETWEEN start_date AND end_date
    AND (t.is_spend OR t.is_income)
  GROUP BY 1, 2
  ORDER BY 1 DESC, 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) TO authenticated;

-- get_user_spending_streak
CREATE OR REPLACE FUNCTION public.get_user_spending_streak()
RETURNS TABLE (current_streak INT, max_streak INT, last_10_days_status BOOLEAN[])
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
DECLARE
    income_val NUMERIC(28,2); actual_income NUMERIC(28,2); fixed_exp NUMERIC(28,2);
    daily_limit NUMERIC(28,2); streak_count INT := 0; max_streak_count INT := 0;
    temp_streak INT := 0; day_idx INT; spend_on_day NUMERIC(28,2);
    status_arr BOOLEAN[] := '{}'; day_date DATE; current_streak_set BOOLEAN := FALSE;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.items_table WHERE user_id = (SELECT auth.uid()) AND is_active = TRUE
    ) THEN RETURN; END IF;

    SELECT COALESCE(monthly_income, 0), COALESCE(monthly_mandatory_expenses, 0)
    INTO income_val, fixed_exp
    FROM public.profiles_table WHERE id = (SELECT auth.uid());

    SELECT COALESCE(SUM(ABS(amount)), 0) INTO actual_income
    FROM public.spendable_income_transactions
    WHERE user_id = (SELECT auth.uid())
      AND date >= DATE_TRUNC('month', CURRENT_DATE)::DATE
      AND date <= (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    income_val := GREATEST(income_val, actual_income);
    daily_limit := (income_val - fixed_exp) / 30.0;
    IF daily_limit <= 0 THEN daily_limit := 50.00; END IF;

    FOR day_idx IN 0..89 LOOP
        day_date := CURRENT_DATE - day_idx;
        SELECT COALESCE(SUM(t.amount), 0) INTO spend_on_day
        FROM public.transactions t
        WHERE t.user_id = (SELECT auth.uid())
          AND t.spend_date = day_date
          AND t.is_spend;

        IF spend_on_day <= daily_limit THEN
            temp_streak := temp_streak + 1;
            IF day_idx < 10 THEN status_arr := array_append(status_arr, TRUE); END IF;
        ELSE
            IF NOT current_streak_set THEN streak_count := temp_streak; current_streak_set := TRUE; END IF;
            IF temp_streak > max_streak_count THEN max_streak_count := temp_streak; END IF;
            temp_streak := 0;
            IF day_idx < 10 THEN status_arr := array_append(status_arr, FALSE); END IF;
        END IF;
    END LOOP;

    IF NOT current_streak_set THEN streak_count := temp_streak; END IF;
    IF temp_streak > max_streak_count THEN max_streak_count := temp_streak; END IF;
    RETURN QUERY SELECT streak_count, max_streak_count, status_arr;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_user_spending_streak() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_spending_streak() TO authenticated;

-- get_pulse_weekly_energy
DROP FUNCTION IF EXISTS public.get_pulse_weekly_energy(date, date);
CREATE OR REPLACE FUNCTION public.get_pulse_weekly_energy(week_start DATE, week_end DATE)
RETURNS TABLE (weekday TEXT, date_label DATE, total_spent DOUBLE PRECISION,
               is_peak BOOLEAN, peak_merchant TEXT, peak_category TEXT, peak_amount DOUBLE PRECISION)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
DECLARE peak_date DATE;
BEGIN
    SELECT t.spend_date INTO peak_date
    FROM public.transactions t
    WHERE t.user_id = auth.uid()
      AND t.spend_date BETWEEN week_start AND week_end
      AND t.is_spend
    GROUP BY t.spend_date
    ORDER BY SUM(t.amount) DESC LIMIT 1;

    RETURN QUERY
    WITH daily_totals AS (
        SELECT t.spend_date AS t_date, SUM(t.amount)::double precision AS t_sum
        FROM public.transactions t
        WHERE t.user_id = auth.uid()
          AND t.spend_date BETWEEN week_start AND week_end
          AND t.is_spend
        GROUP BY t.spend_date
    ),
    peak_transactions AS (
        SELECT DISTINCT ON (t.spend_date)
            t.spend_date AS t_date,
            COALESCE(t.merchant_name, t.name) AS merchant,
            t.personal_finance_category AS category,
            t.amount::double precision AS amount
        FROM public.transactions t
        WHERE t.user_id = auth.uid()
          AND t.spend_date BETWEEN week_start AND week_end
          AND t.is_spend
        ORDER BY t.spend_date, t.amount DESC
    )
    SELECT TO_CHAR(d.date_series, 'Dy'), d.date_series::date,
           COALESCE(dt.t_sum, 0.0)::double precision, (d.date_series::date = peak_date),
           COALESCE(pt.merchant, 'No Spend'), pt.category, COALESCE(pt.amount, 0.0)::double precision
    FROM GENERATE_SERIES(week_start::timestamp, week_end::timestamp, '1 day'::interval) d(date_series)
    LEFT JOIN daily_totals dt ON dt.t_date = d.date_series::date
    LEFT JOIN peak_transactions pt ON pt.t_date = d.date_series::date
    ORDER BY d.date_series ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) TO authenticated;

-- get_pulse_top_merchants
DROP FUNCTION IF EXISTS public.get_pulse_top_merchants(date, date, integer);
CREATE OR REPLACE FUNCTION public.get_pulse_top_merchants(start_date DATE, end_date DATE, lim INTEGER DEFAULT 5)
RETURNS TABLE (merchant_name TEXT, total_spent DOUBLE PRECISION, transaction_count BIGINT, personal_finance_category TEXT)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT COALESCE(t.merchant_name, t.name), SUM(t.amount)::double precision,
           COUNT(*)::bigint, MIN(t.personal_finance_category)
    FROM public.transactions t
    WHERE t.user_id = auth.uid()
      AND t.spend_date BETWEEN start_date AND end_date
      AND t.is_spend
    GROUP BY COALESCE(t.merchant_name, t.name)
    ORDER BY total_spent DESC LIMIT lim;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) TO authenticated;
