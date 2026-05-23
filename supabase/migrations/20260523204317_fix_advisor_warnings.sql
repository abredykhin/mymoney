-- Harden Supabase advisor warnings:
-- - user-facing analytics RPCs should run as invoker with stable search_path
-- - trigger-only functions should not be executable through exposed API roles
-- - RLS auth.uid() calls should be init-plan cached
-- - savings deposit FK should have a covering index

-- User-facing RPCs only read rows allowed by existing RLS policies.
ALTER FUNCTION public.get_daily_transaction_stats(date, date)
  SECURITY INVOKER
  SET search_path = public;

ALTER FUNCTION public.get_monthly_transaction_stats(date, date)
  SECURITY INVOKER
  SET search_path = public;

ALTER FUNCTION public.get_pulse_top_merchants(date, date, integer)
  SECURITY INVOKER
  SET search_path = public;

ALTER FUNCTION public.get_pulse_weekly_energy(date, date)
  SECURITY INVOKER
  SET search_path = public;

ALTER FUNCTION public.get_user_spending_streak()
  SECURITY INVOKER
  SET search_path = public;

-- These RPCs are for signed-in app users only.
REVOKE EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_user_spending_streak() FROM anon;

GRANT EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_spending_streak() TO authenticated;

-- Trigger functions should have stable search_path and not be callable via the API.
ALTER FUNCTION public.handle_new_user()
  SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;

ALTER FUNCTION public.update_goal_current_amount()
  SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.update_goal_current_amount() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_goal_current_amount() FROM anon;
REVOKE EXECUTE ON FUNCTION public.update_goal_current_amount() FROM authenticated;

-- Cache auth.uid() once per statement in RLS policies.
DROP POLICY IF EXISTS "Users can view their own recurring streams"
  ON public.recurring_streams_table;
CREATE POLICY "Users can view their own recurring streams"
  ON public.recurring_streams_table
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own recurring streams"
  ON public.recurring_streams_table;
CREATE POLICY "Users can insert their own recurring streams"
  ON public.recurring_streams_table
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own recurring streams"
  ON public.recurring_streams_table;
CREATE POLICY "Users can update their own recurring streams"
  ON public.recurring_streams_table
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete their own recurring streams"
  ON public.recurring_streams_table;
CREATE POLICY "Users can delete their own recurring streams"
  ON public.recurring_streams_table
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can view their stream transaction links"
  ON public.recurring_stream_transactions_table;
CREATE POLICY "Users can view their stream transaction links"
  ON public.recurring_stream_transactions_table
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.recurring_streams_table rs
      WHERE rs.id = recurring_stream_transactions_table.stream_id
        AND rs.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can manage their own savings goals"
  ON public.savings_goals_table;
CREATE POLICY "Users can manage their own savings goals"
  ON public.savings_goals_table
  FOR ALL
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can manage their own savings deposits"
  ON public.savings_deposits_table;
CREATE POLICY "Users can manage their own savings deposits"
  ON public.savings_deposits_table
  FOR ALL
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX IF NOT EXISTS idx_savings_deposits_user_id
  ON public.savings_deposits_table(user_id);
