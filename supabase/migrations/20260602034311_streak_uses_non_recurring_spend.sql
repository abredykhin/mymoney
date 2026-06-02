-- Align the spending streak with discretionary (variable) spend.
--
-- The streak's daily allowance is discretionary: (income - fixed_expenses)/30.
-- But both spend reads (spend_on_day and spent_before_day) summed *all* is_spend
-- rows, including recurring/fixed obligations that are ALREADY subtracted via the
-- "- fixed_expenses" term. That double-counted fixed bills against a discretionary
-- limit, so a known recurring charge (e.g. $2,650 rent, $538 auto lease) broke the
-- streak on its due date, and large non-recurring outflows drove the monthly-remaining
-- cap negative and zeroed the effective limit for the rest of the month.
--
-- Fix: read discretionary spend from public.variable_transactions (the same source the
-- LiquidHero widget uses), i.e. is_spend AND NOT is_recurring. Once Plaid flags a stream
-- as recurring it drops out of both the hero and the streak, consistently.
--
-- Everything else (per-day per-month income, the GREATEST(0, ...) positive-budget guard,
-- the monthly-remaining cap, the p_today injection point) is unchanged from
-- 20260531175137_require_positive_budget_for_streak.sql.

CREATE OR REPLACE FUNCTION public.get_user_spending_streak(p_today DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (current_streak INT, max_streak INT, last_10_days_status BOOLEAN[])
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
DECLARE
    profile_income NUMERIC(28,2);
    fixed_exp NUMERIC(28,2);
    actual_income NUMERIC(28,2);
    day_income_val NUMERIC(28,2);
    nominal_daily_limit NUMERIC(28,2);
    effective_daily_limit NUMERIC(28,2);
    spent_before_day NUMERIC(28,2);
    month_discretionary NUMERIC(28,2);
    monthly_remaining_before_day NUMERIC(28,2);

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
        SELECT 1 FROM public.items_table WHERE user_id = (SELECT auth.uid()) AND is_active = TRUE
    ) THEN RETURN; END IF;

    SELECT COALESCE(monthly_income, 0), COALESCE(monthly_mandatory_expenses, 0)
    INTO profile_income, fixed_exp
    FROM public.profiles_table WHERE id = (SELECT auth.uid());

    FOR day_idx IN 0..89 LOOP
        day_date := p_today - day_idx;

        SELECT COALESCE(SUM(ABS(amount)), 0) INTO actual_income
        FROM public.spendable_income_transactions
        WHERE user_id = (SELECT auth.uid())
          AND date >= DATE_TRUNC('month', day_date)::DATE
          AND date <= (DATE_TRUNC('month', day_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

        day_income_val := GREATEST(profile_income, actual_income);
        nominal_daily_limit := (day_income_val - fixed_exp) / 30.0;

        -- Discretionary spend before this day (excludes recurring/fixed obligations).
        SELECT COALESCE(SUM(vt.amount), 0) INTO spent_before_day
        FROM public.variable_transactions vt
        WHERE vt.user_id = (SELECT auth.uid())
          AND vt.spend_date >= DATE_TRUNC('month', day_date)::DATE
          AND vt.spend_date < day_date;

        month_discretionary := GREATEST(0, day_income_val - fixed_exp);
        monthly_remaining_before_day := month_discretionary - spent_before_day;
        effective_daily_limit := GREATEST(0, LEAST(nominal_daily_limit, monthly_remaining_before_day));

        -- Discretionary spend on this day (excludes recurring/fixed obligations).
        SELECT COALESCE(SUM(vt.amount), 0) INTO spend_on_day
        FROM public.variable_transactions vt
        WHERE vt.user_id = (SELECT auth.uid())
          AND vt.spend_date = day_date;

        IF effective_daily_limit > 0 AND spend_on_day <= effective_daily_limit THEN
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

REVOKE EXECUTE ON FUNCTION public.get_user_spending_streak(p_today DATE) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_spending_streak(p_today DATE) TO authenticated;
