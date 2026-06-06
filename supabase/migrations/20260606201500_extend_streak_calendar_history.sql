-- Drop old function to allow output signature change
DROP FUNCTION IF EXISTS public.get_user_spending_streak(DATE);

CREATE OR REPLACE FUNCTION public.get_user_spending_streak(p_today DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (current_streak INT, max_streak INT, last_28_days_status BOOLEAN[])
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
DECLARE
    profile_income NUMERIC(28,2);
    fixed_exp NUMERIC(28,2);
    day_income_val NUMERIC(28,2);
    nominal_daily_limit NUMERIC(28,2);
    effective_daily_limit NUMERIC(28,2);
    month_discretionary NUMERIC(28,2);
    monthly_remaining_before_day NUMERIC(28,2);

    streak_count INT := 0;
    max_streak_count INT := 0;
    temp_streak INT := 0;
    day_idx INT;
    status_arr BOOLEAN[] := '{}';
    current_streak_set BOOLEAN := FALSE;
    r RECORD;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.items_table WHERE user_id = (SELECT auth.uid()) AND is_active = TRUE
    ) THEN RETURN; END IF;

    SELECT COALESCE(monthly_income, 0), COALESCE(monthly_mandatory_expenses, 0)
    INTO profile_income, fixed_exp
    FROM public.profiles_table WHERE id = (SELECT auth.uid());

    FOR r IN (
        WITH daily_stats AS (
            SELECT
                d.dt,
                COALESCE(s.daily_spend, 0) AS daily_spend,
                COALESCE(SUM(COALESCE(s.daily_spend, 0)) OVER (
                    PARTITION BY DATE_TRUNC('month', d.dt)
                    ORDER BY d.dt
                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                ), 0) AS spent_before_day,
                COALESCE(inc.actual_income, 0) AS actual_income
            FROM (
                SELECT (DATE_TRUNC('month', p_today - 89)::DATE + idx)::DATE AS dt
                FROM generate_series(0, p_today - DATE_TRUNC('month', p_today - 89)::DATE) AS idx
            ) d
            LEFT JOIN (
                SELECT spend_date, SUM(amount) AS daily_spend
                FROM public.variable_transactions
                WHERE user_id = (SELECT auth.uid())
                  AND spend_date >= DATE_TRUNC('month', p_today - 89)::DATE
                  AND spend_date <= p_today
                GROUP BY spend_date
            ) s ON s.spend_date = d.dt
            LEFT JOIN (
                SELECT DATE_TRUNC('month', date)::DATE AS month_start, SUM(ABS(amount)) AS actual_income
                FROM public.spendable_income_transactions
                WHERE user_id = (SELECT auth.uid())
                  AND date >= DATE_TRUNC('month', p_today - 89)::DATE
                  AND date <= p_today
                GROUP BY DATE_TRUNC('month', date)::DATE
            ) inc ON inc.month_start = DATE_TRUNC('month', d.dt)::DATE
        )
        SELECT dt, daily_spend, spent_before_day, actual_income
        FROM daily_stats
        WHERE dt >= p_today - 89 AND dt <= p_today
        ORDER BY dt DESC
    ) LOOP
        day_idx := p_today - r.dt;

        day_income_val := GREATEST(profile_income, r.actual_income);
        nominal_daily_limit := (day_income_val - fixed_exp) / 30.0;

        month_discretionary := GREATEST(0, day_income_val - fixed_exp);
        monthly_remaining_before_day := month_discretionary - r.spent_before_day;
        effective_daily_limit := GREATEST(0, LEAST(nominal_daily_limit, monthly_remaining_before_day));

        IF effective_daily_limit > 0 AND r.daily_spend <= effective_daily_limit THEN
            temp_streak := temp_streak + 1;
            IF day_idx < 28 THEN status_arr := array_append(status_arr, TRUE); END IF;
        ELSE
            IF NOT current_streak_set THEN streak_count := temp_streak; current_streak_set := TRUE; END IF;
            IF temp_streak > max_streak_count THEN max_streak_count := temp_streak; END IF;
            temp_streak := 0;
            IF day_idx < 28 THEN status_arr := array_append(status_arr, FALSE); END IF;
        END IF;
    END LOOP;

    IF NOT current_streak_set THEN streak_count := temp_streak; END IF;
    IF temp_streak > max_streak_count THEN max_streak_count := temp_streak; END IF;
    RETURN QUERY SELECT streak_count, max_streak_count, status_arr;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_user_spending_streak(p_today DATE) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_spending_streak(p_today DATE) TO authenticated;
