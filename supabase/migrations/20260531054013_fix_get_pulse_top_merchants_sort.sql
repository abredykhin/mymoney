-- Fix the sorting in get_pulse_top_merchants to avoid PL/pgSQL variable collision with RETURNS TABLE column name.
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
    ORDER BY SUM(t.amount) DESC LIMIT lim;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) TO authenticated;
