-- Keep user-facing analytics RPCs under caller permissions.
-- They are intentionally callable by signed-in app users only and all filter on auth.uid().

ALTER FUNCTION public.get_monthly_transaction_stats(date, date)
  SECURITY INVOKER
  SET search_path = public;

ALTER FUNCTION public.get_daily_transaction_stats(date, date)
  SECURITY INVOKER
  SET search_path = public;

ALTER FUNCTION public.get_pulse_top_merchants(date, date, integer)
  SECURITY INVOKER
  SET search_path = public;

ALTER FUNCTION public.get_pulse_weekly_energy(date, date)
  SECURITY INVOKER
  SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) TO authenticated;
