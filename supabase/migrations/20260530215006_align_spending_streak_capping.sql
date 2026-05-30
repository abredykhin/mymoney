-- Redefine get_user_spending_streak to dynamically cap the daily limit
-- by the remaining monthly discretionary budget, matching the iOS client's capping logic.

CREATE OR REPLACE FUNCTION public.get_user_spending_streak()
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

    -- Fetch the baseline values from the profile once
    SELECT COALESCE(monthly_income, 0), COALESCE(monthly_mandatory_expenses, 0)
    INTO profile_income, fixed_exp
    FROM public.profiles_table WHERE id = (SELECT auth.uid());

    FOR day_idx IN 0..89 LOOP
        day_date := CURRENT_DATE - day_idx;

        -- 1. Fetch actual income in the month of day_date
        SELECT COALESCE(SUM(ABS(amount)), 0) INTO actual_income
        FROM public.spendable_income_transactions
        WHERE user_id = (SELECT auth.uid())
          AND date >= DATE_TRUNC('month', day_date)::DATE
          and date <= (DATE_TRUNC('month', day_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

        -- 2. Use the greatest of profile expected monthly income or actual paychecks in that month
        day_income_val := GREATEST(profile_income, actual_income);
        
        -- 3. Calculate nominal daily limit
        nominal_daily_limit := (day_income_val - fixed_exp) / 30.0;
        IF nominal_daily_limit <= 0 THEN nominal_daily_limit := 50.00; END IF;

        -- 4. Calculate total spent in the month of day_date before day_date started
        SELECT COALESCE(SUM(t.amount), 0) INTO spent_before_day
        FROM public.transactions t
        WHERE t.user_id = (SELECT auth.uid())
          AND t.spend_date >= DATE_TRUNC('month', day_date)::DATE
          AND t.spend_date < day_date
          AND t.is_spend;

        -- 5. Calculate monthly discretionary and remaining discretionary budget
        month_discretionary := GREATEST(0, day_income_val - fixed_exp);
        monthly_remaining_before_day := month_discretionary - spent_before_day;

        -- 6. Cap the daily limit by remaining monthly discretionary space (floor to 0)
        effective_daily_limit := GREATEST(0, LEAST(nominal_daily_limit, monthly_remaining_before_day));

        -- 7. Fetch the spend on day_date itself
        SELECT COALESCE(SUM(t.amount), 0) INTO spend_on_day
        FROM public.transactions t
        WHERE t.user_id = (SELECT auth.uid())
          AND t.spend_date = day_date
          AND t.is_spend;

        -- 8. Evaluate if this day was under budget relative to its effective limit
        IF spend_on_day <= effective_daily_limit THEN
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
