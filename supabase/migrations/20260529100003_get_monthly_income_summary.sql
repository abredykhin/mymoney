-- Push income aggregation into the DB so any platform gets pre-bucketed
-- known/extra income instead of fetching raw rows and reducing client-side.
--
-- Mirrors BudgetService.fetchActualIncome():
--   known_income  → spendable income transactions where is_recurring = true
--   extra_income  → spendable income transactions where is_recurring is false or null
--
-- The spendable_income_transactions view already excludes:
--   · credit / loan account inflows
--   · brokerage / wire / transfer / invest name patterns
--   · any transaction not categorised as INCOME

CREATE OR REPLACE FUNCTION public.get_monthly_income_summary(p_start date, p_end date)
RETURNS TABLE (
    known_income double precision,
    extra_income double precision
)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(CASE WHEN t.is_recurring = true
                     THEN ABS(t.amount) ELSE 0 END), 0)::double precision AS known_income,
        COALESCE(SUM(CASE WHEN t.is_recurring IS DISTINCT FROM true
                     THEN ABS(t.amount) ELSE 0 END), 0)::double precision AS extra_income
    FROM public.spendable_income_transactions t
    WHERE t.user_id    = auth.uid()
      AND t.spend_date BETWEEN p_start AND p_end;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_monthly_income_summary(date, date) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_monthly_income_summary(date, date) TO authenticated;
