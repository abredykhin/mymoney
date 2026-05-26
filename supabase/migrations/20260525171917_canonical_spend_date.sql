-- Canonical user-facing transaction date for spending rollups.
--
-- Plaid/bank "date" and "authorized_date" can be an effective/posting date,
-- especially for pending credit-card rows. For daily budgeting, the app should
-- count a pending transaction on the local day we first observed it if Plaid
-- sends a future effective date. Once a transaction posts, Plaid's final date
-- remains the source of truth.

CREATE OR REPLACE FUNCTION public.compute_transaction_spend_date(
  tx_date date,
  tx_authorized_date date,
  tx_pending boolean,
  tx_created_at timestamptz,
  local_timezone text DEFAULT 'America/Los_Angeles'
)
RETURNS date
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT
    CASE
      WHEN COALESCE(tx_authorized_date, tx_date) IS NULL THEN NULL
      WHEN COALESCE(tx_pending, false)
        AND tx_created_at IS NOT NULL
        AND COALESCE(tx_authorized_date, tx_date) > (tx_created_at AT TIME ZONE local_timezone)::date
        THEN (tx_created_at AT TIME ZONE local_timezone)::date
      ELSE COALESCE(tx_authorized_date, tx_date)
    END;
$$;

ALTER TABLE public.transactions_table
  ADD COLUMN IF NOT EXISTS spend_date date;

UPDATE public.transactions_table
SET spend_date = public.compute_transaction_spend_date(date, authorized_date, pending, created_at)
WHERE spend_date IS DISTINCT FROM public.compute_transaction_spend_date(date, authorized_date, pending, created_at);

CREATE OR REPLACE FUNCTION public.set_transaction_spend_date()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.spend_date := public.compute_transaction_spend_date(
    NEW.date,
    NEW.authorized_date,
    NEW.pending,
    COALESCE(NEW.created_at, now())
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_transaction_spend_date_trigger ON public.transactions_table;
CREATE TRIGGER set_transaction_spend_date_trigger
BEFORE INSERT OR UPDATE OF date, authorized_date, pending, created_at
ON public.transactions_table
FOR EACH ROW
EXECUTE FUNCTION public.set_transaction_spend_date();

CREATE INDEX IF NOT EXISTS idx_transactions_table_user_spend_date
  ON public.transactions_table (user_id, spend_date DESC)
  WHERE spend_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_table_account_spend_date
  ON public.transactions_table (account_id, spend_date DESC)
  WHERE spend_date IS NOT NULL;

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
    t.spend_date
  FROM public.transactions_table t
  LEFT JOIN public.accounts a ON t.account_id = a.id;

CREATE OR REPLACE VIEW public.variable_transactions
WITH (security_invoker = true)
AS
SELECT t.*
FROM public.transactions t
WHERE
  (t.is_recurring = FALSE OR t.is_recurring IS NULL)
  AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
  AND t.personal_finance_subcategory IS DISTINCT FROM 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT';

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
      '%invest%',
      '%healthequity%'
    ])
    OR COALESCE(t.merchant_name, '') ILIKE ANY (ARRAY[
      '%transfer%',
      '%wire%',
      '%reversal%',
      '%brokerage%',
      '%bkrg%',
      '%schwab%',
      '%moneylink%',
      '%invest%',
      '%healthequity%'
    ])
  );

GRANT SELECT ON public.transactions TO authenticated;
GRANT SELECT ON public.variable_transactions TO authenticated;
GRANT SELECT ON public.spendable_income_transactions TO authenticated;

DROP FUNCTION IF EXISTS public.get_monthly_transaction_stats(date, date);
DROP FUNCTION IF EXISTS public.get_daily_transaction_stats(date, date);

CREATE OR REPLACE FUNCTION public.get_monthly_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (
  year double precision,
  month double precision,
  total_in double precision,
  total_out double precision
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    EXTRACT(YEAR FROM t.spend_date)::double precision as year,
    EXTRACT(MONTH FROM t.spend_date)::double precision as month,
    COALESCE(SUM(
      CASE
        WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
        WHEN (a.type ILIKE 'depository' OR a.type ILIKE 'investment') AND t.amount < 0 THEN ABS(t.amount)
        ELSE 0
      END
    ), 0)::double precision as total_in,
    COALESCE(SUM(
      CASE
        WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        WHEN a.type ILIKE 'investment' THEN 0
        WHEN t.amount > 0 THEN t.amount
        ELSE 0
      END
    ), 0)::double precision as total_out
  FROM public.transactions_table t
  JOIN public.accounts_table a ON t.account_id = a.id
  WHERE t.user_id = auth.uid()
    AND t.spend_date BETWEEN start_date AND end_date
    AND (
      (
        t.personal_finance_category IS NOT NULL
        AND t.personal_finance_category NOT ILIKE '%TRANSFER%'
        AND t.personal_finance_category NOT ILIKE 'LOAN_PAYMENTS%'
      )
      OR
      (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
    AND NOT (
      t.personal_finance_category = 'INCOME'
      AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
        '%transfer%',
        '%wire%',
        '%reversal%',
        '%brokerage%',
        '%bkrg%',
        '%schwab%',
        '%moneylink%',
        '%invest%',
        '%healthequity%'
      ])
    )
  GROUP BY 1, 2
  ORDER BY 1 DESC, 2 DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_daily_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (
  date date,
  total_in double precision,
  total_out double precision
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.spend_date as date,
    COALESCE(SUM(
      CASE
        WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
        WHEN (a.type ILIKE 'depository' OR a.type ILIKE 'investment') AND t.amount < 0 THEN ABS(t.amount)
        ELSE 0
      END
    ), 0)::double precision as total_in,
    COALESCE(SUM(
      CASE
        WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
        WHEN a.type ILIKE 'investment' THEN 0
        WHEN t.amount > 0 THEN t.amount
        ELSE 0
      END
    ), 0)::double precision as total_out
  FROM public.transactions_table t
  JOIN public.accounts_table a ON t.account_id = a.id
  WHERE t.user_id = auth.uid()
    AND t.spend_date BETWEEN start_date AND end_date
    AND (
      (
        t.personal_finance_category IS NOT NULL
        AND t.personal_finance_category NOT ILIKE '%TRANSFER%'
        AND t.personal_finance_category NOT ILIKE 'LOAN_PAYMENTS%'
      )
      OR
      (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
    AND NOT (
      t.personal_finance_category = 'INCOME'
      AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
        '%transfer%',
        '%wire%',
        '%reversal%',
        '%brokerage%',
        '%bkrg%',
        '%schwab%',
        '%moneylink%',
        '%invest%',
        '%healthequity%'
      ])
    )
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_pulse_weekly_energy(
    week_start date,
    week_end date
)
RETURNS TABLE (
    weekday text,
    date_label date,
    total_spent double precision,
    is_peak boolean,
    peak_merchant text,
    peak_category text,
    peak_amount double precision
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    peak_date date;
BEGIN
    SELECT t.spend_date INTO peak_date
    FROM public.transactions_table t
    WHERE t.user_id = auth.uid()
      AND t.spend_date BETWEEN week_start AND week_end
      AND t.amount > 0
      AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    GROUP BY t.spend_date
    ORDER BY SUM(t.amount) DESC
    LIMIT 1;

    RETURN QUERY
    WITH daily_totals AS (
        SELECT
            t.spend_date as t_date,
            SUM(t.amount)::double precision as t_sum
        FROM public.transactions_table t
        WHERE t.user_id = auth.uid()
          AND t.spend_date BETWEEN week_start AND week_end
          AND t.amount > 0
          AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
        GROUP BY t.spend_date
    ),
    peak_transactions AS (
        SELECT DISTINCT ON (t.spend_date)
            t.spend_date as t_date,
            COALESCE(t.merchant_name, t.name) as merchant,
            t.personal_finance_category as category,
            t.amount::double precision as amount
        FROM public.transactions_table t
        WHERE t.user_id = auth.uid()
          AND t.spend_date BETWEEN week_start AND week_end
          AND t.amount > 0
        ORDER BY t.spend_date, t.amount DESC
    )
    SELECT
        TO_CHAR(d.date_series, 'Dy') as weekday,
        d.date_series::date as date_label,
        COALESCE(dt.t_sum, 0.0)::double precision as total_spent,
        (d.date_series::date = peak_date) as is_peak,
        COALESCE(pt.merchant, 'No Spend') as peak_merchant,
        pt.category as peak_category,
        COALESCE(pt.amount, 0.0)::double precision as peak_amount
    FROM GENERATE_SERIES(week_start::timestamp, week_end::timestamp, '1 day'::interval) d(date_series)
    LEFT JOIN daily_totals dt ON dt.t_date = d.date_series::date
    LEFT JOIN peak_transactions pt ON pt.t_date = d.date_series::date
    ORDER BY d.date_series ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_pulse_top_merchants(
    start_date date,
    end_date date,
    lim integer DEFAULT 5
)
RETURNS TABLE (
    merchant_name text,
    total_spent double precision,
    transaction_count bigint,
    personal_finance_category text
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(t.merchant_name, t.name) as merchant_name,
        SUM(t.amount)::double precision as total_spent,
        COUNT(*)::bigint as transaction_count,
        MIN(t.personal_finance_category) as personal_finance_category
    FROM public.transactions_table t
    WHERE t.user_id = auth.uid()
      AND t.spend_date BETWEEN start_date AND end_date
      AND t.amount > 0
      AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    GROUP BY COALESCE(t.merchant_name, t.name)
    ORDER BY total_spent DESC
    LIMIT lim;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_spending_streak()
RETURNS TABLE (
    current_streak int,
    max_streak int,
    last_10_days_status boolean[]
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    income_val numeric(28,2);
    actual_income numeric(28,2);
    fixed_exp numeric(28,2);
    daily_limit numeric(28,2);
    streak_count int := 0;
    max_streak_count int := 0;
    temp_streak int := 0;
    day_idx int;
    spend_on_day numeric(28,2);
    status_arr boolean[] := '{}';
    day_date date;
    current_streak_set boolean := false;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.items_table
        WHERE user_id = (SELECT auth.uid())
          AND is_active = true
    ) THEN
        RETURN;
    END IF;

    SELECT COALESCE(monthly_income, 0), COALESCE(monthly_mandatory_expenses, 0)
    INTO income_val, fixed_exp
    FROM public.profiles_table
    WHERE id = (SELECT auth.uid());

    SELECT COALESCE(SUM(ABS(amount)), 0)
    INTO actual_income
    FROM public.spendable_income_transactions
    WHERE user_id = (SELECT auth.uid())
      AND spend_date >= DATE_TRUNC('month', CURRENT_DATE)::date
      AND spend_date <= (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::date;

    income_val := GREATEST(income_val, actual_income);

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
          AND spend_date = day_date
          AND amount > 0
          AND (personal_finance_category IS NULL OR personal_finance_category NOT ILIKE '%TRANSFER%');

        IF spend_on_day <= daily_limit THEN
            temp_streak := temp_streak + 1;
            IF day_idx < 10 THEN
                status_arr := array_append(status_arr, true);
            END IF;
        ELSE
            IF NOT current_streak_set THEN
                streak_count := temp_streak;
                current_streak_set := true;
            END IF;

            IF temp_streak > max_streak_count THEN
                max_streak_count := temp_streak;
            END IF;

            temp_streak := 0;
            IF day_idx < 10 THEN
                status_arr := array_append(status_arr, false);
            END IF;
        END IF;
    END LOOP;

    IF NOT current_streak_set THEN
        streak_count := temp_streak;
    END IF;

    IF temp_streak > max_streak_count THEN
        max_streak_count := temp_streak;
    END IF;

    RETURN QUERY SELECT streak_count, max_streak_count, status_arr;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_user_spending_streak() FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_user_spending_streak() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_spending_streak() TO authenticated;
