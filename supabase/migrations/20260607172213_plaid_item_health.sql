ALTER TABLE public.items_table
  ADD COLUMN IF NOT EXISTS plaid_health_updated_at timestamptz,
  ADD COLUMN IF NOT EXISTS plaid_last_error_code text,
  ADD COLUMN IF NOT EXISTS plaid_last_error_message text,
  ADD COLUMN IF NOT EXISTS plaid_access_expires_at timestamptz;

ALTER TABLE public.accounts_table
  ADD COLUMN IF NOT EXISTS plaid_access_revoked_at timestamptz;

UPDATE public.items_table
SET status = lower(status)
WHERE status <> lower(status);

CREATE INDEX IF NOT EXISTS idx_items_status_user_id
  ON public.items_table(user_id, status);

CREATE TABLE IF NOT EXISTS public.plaid_webhook_events (
  id bigserial PRIMARY KEY,
  plaid_item_id text,
  webhook_type text NOT NULL,
  webhook_code text NOT NULL,
  environment text,
  payload jsonb NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  processing_error text
);

ALTER TABLE public.plaid_webhook_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can manage plaid webhook events" ON public.plaid_webhook_events;
CREATE POLICY "Service role can manage plaid webhook events"
  ON public.plaid_webhook_events
  FOR ALL
  USING ((select auth.role()) = 'service_role')
  WITH CHECK ((select auth.role()) = 'service_role');

CREATE INDEX IF NOT EXISTS idx_plaid_webhook_events_item_received
  ON public.plaid_webhook_events(plaid_item_id, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_plaid_webhook_events_type_code
  ON public.plaid_webhook_events(webhook_type, webhook_code, received_at DESC);

CREATE OR REPLACE VIEW public.accounts_with_banks AS
SELECT
    a.id,
    a.item_id,
    a.name,
    a.mask,
    a.official_name,
    a.current_balance,
    a.available_balance,
    a.type,
    a.subtype,
    a.hidden,
    a.plaid_account_id as account_id,
    a.iso_currency_code,
    a.created_at,
    a.updated_at,
    i.id as institution_id,
    i.name as institution_name,
    i.logo as institution_logo,
    i.primary_color as institution_color,
    i.url as institution_url,
    it.user_id,
    it.plaid_item_id,
    it.status as item_status,
    it.plaid_health_updated_at,
    it.plaid_last_error_code,
    it.plaid_last_error_message,
    it.plaid_access_expires_at,
    a.plaid_access_revoked_at
FROM public.accounts_table a
JOIN public.items_table it ON a.item_id = it.id
JOIN public.institutions_table i ON it.plaid_institution_id = i.institution_id;

ALTER VIEW public.accounts_with_banks SET (security_invoker = true);
GRANT SELECT ON public.accounts_with_banks TO authenticated;

COMMENT ON COLUMN public.items_table.status IS 'Plaid Item health state: good, needs_reauth, pending_disconnect, pending_expiration, permission_revoked, new_accounts_available.';
COMMENT ON TABLE public.plaid_webhook_events IS 'Raw Plaid webhook receipts for audit and processing diagnostics.';
