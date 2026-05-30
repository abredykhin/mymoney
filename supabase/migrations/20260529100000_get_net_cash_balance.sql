-- Push net-cash-balance aggregation into the DB so any platform (iOS, Android, web)
-- can call a single RPC instead of fetching all account rows and reducing client-side.
--
-- Logic mirrors BudgetService.fetchTotalBalance():
--   depository accounts  → positive (money we have)
--   credit accounts      → negative (debt we owe)
--   investment / loan    → excluded from liquid-cash metric

CREATE OR REPLACE FUNCTION public.get_net_cash_balance()
RETURNS TABLE (
    balance          double precision,
    iso_currency_code text,
    as_of            text
)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(
            CASE
                WHEN a.type ILIKE 'depository' THEN  a.current_balance::double precision
                WHEN a.type ILIKE 'credit'     THEN -a.current_balance::double precision
                ELSE 0::double precision
            END
        ), 0)::double precision                                     AS balance,
        'USD'::text                                                 AS iso_currency_code,
        TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS as_of
    FROM public.accounts a
    WHERE a.user_id = auth.uid()
      AND a.hidden = false;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_net_cash_balance() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_net_cash_balance() TO authenticated;
