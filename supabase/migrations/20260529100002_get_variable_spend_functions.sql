-- Two functions that replace 4 separate client-side queries in fetchAllPeriodSpend().
--
-- get_variable_spend(p_start, p_end)
--   Scalar aggregate over variable_transactions for a single window.
--   Replaces fetchVariableSpendRaw() / fetchVariableSpend().
--
-- get_period_spend_comparison(...)
--   Returns all four comparison windows (prev week, prev month, current week, today)
--   in a single round trip using conditional SUM, replacing four concurrent
--   fetchVariableSpendRaw() calls in fetchAllPeriodSpend().

CREATE OR REPLACE FUNCTION public.get_variable_spend(p_start date, p_end date)
RETURNS double precision
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
DECLARE
    result double precision;
BEGIN
    SELECT COALESCE(SUM(ABS(t.amount)), 0)::double precision
    INTO result
    FROM public.variable_transactions t
    WHERE t.user_id    = auth.uid()
      AND t.spend_date BETWEEN p_start AND p_end;
    RETURN result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_variable_spend(date, date) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_variable_spend(date, date) TO authenticated;


CREATE OR REPLACE FUNCTION public.get_period_spend_comparison(
    p_prev_week_start        date,
    p_prev_week_same_day_end date,
    p_prev_month_start       date,
    p_prev_month_same_day_end date,
    p_current_week_start     date,
    p_today                  date
)
RETURNS TABLE (
    prev_week    double precision,
    prev_month   double precision,
    current_week double precision,
    today        double precision
)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(CASE
            WHEN t.spend_date BETWEEN p_prev_week_start AND p_prev_week_same_day_end
            THEN ABS(t.amount) ELSE 0 END), 0)::double precision  AS prev_week,
        COALESCE(SUM(CASE
            WHEN t.spend_date BETWEEN p_prev_month_start AND p_prev_month_same_day_end
            THEN ABS(t.amount) ELSE 0 END), 0)::double precision  AS prev_month,
        COALESCE(SUM(CASE
            WHEN t.spend_date BETWEEN p_current_week_start AND p_today
            THEN ABS(t.amount) ELSE 0 END), 0)::double precision  AS current_week,
        COALESCE(SUM(CASE
            WHEN t.spend_date = p_today
            THEN ABS(t.amount) ELSE 0 END), 0)::double precision  AS today
    FROM public.variable_transactions t
    WHERE t.user_id    = auth.uid()
      AND t.spend_date >= LEAST(p_prev_week_start, p_prev_month_start);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_period_spend_comparison(date, date, date, date, date, date) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_period_spend_comparison(date, date, date, date, date, date) TO authenticated;
