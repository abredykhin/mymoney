-- Fix spending streak calculation in get_user_spending_streak
-- The current streak must be active as of today. If today is over budget, the current active streak is 0.
-- We use a boolean flag current_streak_set to capture the streak ending at today (or yesterday if today is still under budget).

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
          AND (personal_finance_category IS NULL OR personal_finance_category NOT ILIKE '%TRANSFER%');

        IF spend_on_day <= daily_limit THEN
            temp_streak := temp_streak + 1;
            IF day_idx < 10 THEN
                status_arr := array_append(status_arr, TRUE);
            END IF;
        ELSE
            -- We hit an over-budget day.
            -- The first over-budget day we encounter going backwards from today determines the end of the current active streak.
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

    -- If the streak was never broken (e.g., under budget for all 90 days), set it to the total accumulated.
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
