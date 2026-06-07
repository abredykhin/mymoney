DROP POLICY IF EXISTS "Service role can manage plaid webhook events" ON public.plaid_webhook_events;

CREATE POLICY "Service role can manage plaid webhook events"
  ON public.plaid_webhook_events
  FOR ALL
  USING ((select auth.role()) = 'service_role')
  WITH CHECK ((select auth.role()) = 'service_role');
