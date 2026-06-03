-- Store Plaid transaction timestamps and use authorized_datetime for the canonical local spend date.
--
-- Plaid date-only fields can be UTC/effective dates. When authorized_datetime is
-- available, it carries the exact authorization instant and should decide the
-- local day used by daily spend surfaces. The posted datetime is stored for
-- inspection but does not drive spend_date.

ALTER TABLE public.profiles_table
  ADD COLUMN IF NOT EXISTS time_zone text;

ALTER TABLE public.transactions_table
  ADD COLUMN IF NOT EXISTS authorized_datetime timestamptz,
  ADD COLUMN IF NOT EXISTS datetime timestamptz;

DROP TRIGGER IF EXISTS set_transaction_spend_date_trigger ON public.transactions_table;
DROP FUNCTION IF EXISTS public.set_transaction_spend_date();
DROP FUNCTION IF EXISTS public.compute_transaction_spend_date(date, date, boolean, timestamptz, text);
DROP FUNCTION IF EXISTS public.compute_transaction_spend_date(date, date, timestamptz, timestamptz, boolean, timestamptz, text);
DROP FUNCTION IF EXISTS public.profile_time_zone_for_user(uuid);

CREATE OR REPLACE FUNCTION public.compute_transaction_spend_date(
  tx_date date,
  tx_authorized_date date,
  tx_authorized_datetime timestamptz,
  tx_pending boolean,
  tx_created_at timestamptz,
  local_timezone text DEFAULT 'UTC'
)
RETURNS date
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT
    CASE
      WHEN tx_authorized_datetime IS NOT NULL
        THEN (tx_authorized_datetime AT TIME ZONE local_timezone)::date
      WHEN COALESCE(tx_authorized_date, tx_date) IS NULL
        THEN NULL
      WHEN COALESCE(tx_pending, false)
        AND tx_created_at IS NOT NULL
        AND COALESCE(tx_authorized_date, tx_date) > (tx_created_at AT TIME ZONE local_timezone)::date
        THEN (tx_created_at AT TIME ZONE local_timezone)::date
      ELSE COALESCE(tx_authorized_date, tx_date)
    END;
$$;

CREATE OR REPLACE FUNCTION public.profile_time_zone_for_user(profile_user_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (
      SELECT p.time_zone
      FROM public.profiles_table p
      JOIN pg_timezone_names z ON z.name = p.time_zone
      WHERE p.id = profile_user_id
      LIMIT 1
    ),
    'UTC'
  );
$$;

CREATE OR REPLACE FUNCTION public.set_transaction_spend_date()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  profile_timezone text;
BEGIN
  profile_timezone := public.profile_time_zone_for_user(NEW.user_id);

  NEW.spend_date := public.compute_transaction_spend_date(
    NEW.date,
    NEW.authorized_date,
    NEW.authorized_datetime,
    NEW.pending,
    COALESCE(NEW.created_at, now()),
    profile_timezone
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER set_transaction_spend_date_trigger
BEFORE INSERT OR UPDATE OF date, authorized_date, authorized_datetime, datetime, pending, created_at
ON public.transactions_table
FOR EACH ROW
EXECUTE FUNCTION public.set_transaction_spend_date();

UPDATE public.transactions_table
SET spend_date = public.compute_transaction_spend_date(
  date,
  authorized_date,
  authorized_datetime,
  pending,
  created_at,
  public.profile_time_zone_for_user(user_id)
)
WHERE spend_date IS DISTINCT FROM public.compute_transaction_spend_date(
  date,
  authorized_date,
  authorized_datetime,
  pending,
  created_at,
  public.profile_time_zone_for_user(user_id)
);

CREATE OR REPLACE VIEW public.profiles
WITH (security_invoker = true)
AS
  SELECT
    id,
    username,
    monthly_income,
    monthly_mandatory_expenses,
    created_at,
    updated_at,
    tracked_spending_categories,
    first_name,
    spending_plan_mode,
    time_zone
  FROM
    public.profiles_table;

CREATE OR REPLACE VIEW public.transactions
WITH (security_invoker = true)
AS
SELECT
  t.id,
  t.account_id,
  a.user_id,
  a.plaid_account_id,
  a.item_id,
  a.plaid_item_id,
  a.type,
  t.amount,
  t.is_recurring,
  t.iso_currency_code,
  t.date,
  t.authorized_date,
  t.name,
  t.merchant_name,
  t.logo_url,
  t.website,
  t.payment_channel,
  t.transaction_id,
  t.personal_finance_category,
  t.personal_finance_subcategory,
  t.pending,
  t.pending_transaction_transaction_id,
  t.created_at,
  t.updated_at,
  t.spend_date,

  (
    t.amount > 0
    AND COALESCE(a.type, '') NOT ILIKE 'investment'
    AND (
      (
        t.personal_finance_category IS NOT NULL
        AND NOT (
          t.personal_finance_category = 'TRANSFER_IN'
          AND COALESCE(t.personal_finance_subcategory, '') != 'TRANSFER_IN_ACCOUNT_TRANSFER'
        )
        AND NOT (
          COALESCE(t.personal_finance_subcategory, '') = 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
        )
        AND NOT (
          t.personal_finance_category = 'TRANSFER_OUT'
          AND COALESCE(t.personal_finance_subcategory, '') NOT IN (
            'TRANSFER_OUT_ACCOUNT_TRANSFER',
            'TRANSFER_OUT_WITHDRAWAL',
            'TRANSFER_OUT_OTHER_TRANSFER_OUT'
          )
        )
        AND NOT (
          t.personal_finance_category = 'INCOME'
          AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
            '%transfer%', '%wire%', '%reversal%', '%brokerage%',
            '%bkrg%', '%schwab%', '%moneylink%', '%invest%'
          ])
        )
      )
      OR (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
  ) AS is_spend,

  (
    t.amount < 0
    AND COALESCE(a.type, '') NOT ILIKE 'credit'
    AND COALESCE(a.type, '') NOT ILIKE 'loan'
    AND (
      t.personal_finance_subcategory = 'TRANSFER_IN_ACCOUNT_TRANSFER'
      OR (
        t.personal_finance_category = 'INCOME'
        AND NOT (
          COALESCE(t.name, '') ILIKE ANY (ARRAY[
            '%transfer%', '%wire%', '%reversal%', '%brokerage%',
            '%bkrg%', '%schwab%', '%moneylink%', '%invest%'
          ])
        )
      )
    )
  ) AS is_income,

  t.authorized_datetime,
  t.datetime

FROM public.transactions_table t
LEFT JOIN public.accounts a ON t.account_id = a.id;

CREATE OR REPLACE VIEW public.variable_transactions
WITH (security_invoker = true)
AS
SELECT t.*
FROM public.transactions t
WHERE t.is_spend
  AND (t.is_recurring = FALSE OR t.is_recurring IS NULL)
  AND COALESCE(t.personal_finance_subcategory, '') <> 'TRANSFER_OUT_OTHER_TRANSFER_OUT';

CREATE OR REPLACE VIEW public.spendable_income_transactions
WITH (security_invoker = true)
AS
SELECT t.*
FROM public.transactions t
WHERE t.amount < 0
  AND COALESCE(t.type, '') NOT IN ('credit', 'loan')
  AND t.personal_finance_category = 'INCOME'
  AND NOT (
    COALESCE(t.name, '') ILIKE ANY (ARRAY[
      '%transfer%',
      '%wire%',
      '%reversal%',
      '%brokerage%',
      '%bkrg%',
      '%schwab%',
      '%moneylink%',
      '%invest%'
    ])
    OR COALESCE(t.merchant_name, '') ILIKE ANY (ARRAY[
      '%transfer%',
      '%wire%',
      '%reversal%',
      '%brokerage%',
      '%bkrg%',
      '%schwab%',
      '%moneylink%',
      '%invest%'
    ])
  );

GRANT SELECT ON public.transactions TO authenticated;
GRANT SELECT ON public.variable_transactions TO authenticated;
GRANT SELECT ON public.spendable_income_transactions TO authenticated;
