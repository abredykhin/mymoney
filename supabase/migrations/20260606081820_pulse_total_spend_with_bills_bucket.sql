-- Pulse "Swing" reverts to TOTAL spend, with a first-class "Bills" classification.
--
-- Product decision (2026-06-06): the Pulse Damage Report + day-by-day Energy show
-- ALL spending (is_spend), and "Where it went" breaks bills out as their own bucket
-- so the categories still sum to the Damage Report headline. This REVERSES the
-- 2026-06-03 change (20260603100000_pulse_spend_uses_discretionary.sql) that had
-- pointed these two RPCs at variable_transactions.
--
-- The discretionary surfaces (Liquid Hero, Money-Left breakdown, Cushion) are
-- UNCHANGED: they still read variable_transactions, whose WHERE clause is left
-- byte-for-byte intact below. The only structural change to the transactions view
-- is an ADDITIVE `is_mandatory` passthrough column — existing consumers select
-- specific columns and never read it, so their results are unaffected.
--
-- is_mandatory is the exact complement of the variable_transactions exclusion:
--   a spend row is "mandatory" (a bill) when it is_recurring, OR when its merchant
--   matches an active mandatory expense stream (the pending-bill safety net from
--   20260603013224). variable_transactions = is_spend AND NOT is_mandatory.

-- ── transactions view: add is_mandatory (additive, passthrough) ───────────────
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
  t.datetime,

  -- Bill / mandatory classification — complement of variable_transactions' exclusion.
  -- Matches a row to an active mandatory expense stream by merchant even before Plaid
  -- links it to a stream (is_recurring still FALSE for fresh pending bills).
  -- MUST stay last: CREATE OR REPLACE VIEW only permits appending new columns.
  (
    t.is_recurring = TRUE
    OR EXISTS (
      SELECT 1
      FROM public.active_mandatory_expense_streams ames
      WHERE ames.user_id = a.user_id
        AND (ames.user_marked_recurring = TRUE OR ames.user_marked_recurring IS NULL)
        AND NULLIF(BTRIM(ames.merchant_name), '') IS NOT NULL
        AND LOWER(BTRIM(t.merchant_name)) = LOWER(BTRIM(ames.merchant_name))
    )
  ) AS is_mandatory

FROM public.transactions_table t
LEFT JOIN public.accounts a ON t.account_id = a.id;

GRANT SELECT ON public.transactions TO authenticated;

-- variable_transactions is intentionally re-declared with its CURRENT definition
-- (from 20260603013224) so the CREATE OR REPLACE above doesn't leave it stale. Its
-- WHERE clause is unchanged: discretionary = is_spend, not-recurring, and not matching
-- an active mandatory stream. (Equivalent to is_spend AND NOT is_mandatory.)
CREATE OR REPLACE VIEW public.variable_transactions
WITH (security_invoker = true)
AS
SELECT t.*
FROM public.transactions t
WHERE t.is_spend
  AND (t.is_recurring = FALSE OR t.is_recurring IS NULL)
  AND NOT EXISTS (
    SELECT 1
    FROM public.active_mandatory_expense_streams ames
    WHERE ames.user_id = t.user_id
      AND (ames.user_marked_recurring = TRUE OR ames.user_marked_recurring IS NULL)
      AND NULLIF(BTRIM(ames.merchant_name), '') IS NOT NULL
      AND LOWER(BTRIM(t.merchant_name)) = LOWER(BTRIM(ames.merchant_name))
  );

GRANT SELECT ON public.variable_transactions TO authenticated;

-- ── Damage report headline / net → TOTAL spend ───────────────────────────────
-- total_out sums ALL spend (transactions WHERE is_spend), not the discretionary
-- subset. total_in stays the income layer so net In−Out still makes sense.
CREATE OR REPLACE FUNCTION public.get_daily_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (date date, total_in double precision, total_out double precision)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH inflow AS (
    SELECT t.spend_date AS d, SUM(ABS(t.amount))::double precision AS amt
    FROM public.transactions t
    WHERE t.user_id = auth.uid()
      AND t.spend_date BETWEEN start_date AND end_date
      AND t.is_income
    GROUP BY t.spend_date
  ),
  outflow AS (
    SELECT t.spend_date AS d, SUM(ABS(t.amount))::double precision AS amt
    FROM public.transactions t
    WHERE t.user_id = auth.uid()
      AND t.spend_date BETWEEN start_date AND end_date
      AND t.is_spend
    GROUP BY t.spend_date
  )
  SELECT
    COALESCE(i.d, o.d) AS date,
    COALESCE(i.amt, 0)::double precision AS total_in,
    COALESCE(o.amt, 0)::double precision AS total_out
  FROM inflow i
  FULL OUTER JOIN outflow o ON i.d = o.d
  ORDER BY 1;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) TO authenticated;

-- ── Day-by-day energy bars → TOTAL spend ─────────────────────────────────────
-- Rebased on total is_spend so the day bars sum to the Damage Report headline.
DROP FUNCTION IF EXISTS public.get_pulse_weekly_energy(date, date);
CREATE OR REPLACE FUNCTION public.get_pulse_weekly_energy(
    week_start DATE,
    week_end DATE
)
RETURNS TABLE (
    weekday TEXT,
    date_label DATE,
    total_spent DOUBLE PRECISION,
    is_peak BOOLEAN,
    peak_merchant TEXT,
    peak_category TEXT,
    peak_amount DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY INVOKER SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    peak_date DATE;
BEGIN
    -- Highest total-spend day in the range.
    SELECT t.spend_date INTO peak_date
    FROM public.transactions t
    WHERE t.user_id = v_uid
      AND t.is_spend
      AND t.spend_date BETWEEN week_start AND week_end
    GROUP BY t.spend_date
    ORDER BY SUM(ABS(t.amount)) DESC
    LIMIT 1;

    RETURN QUERY
    WITH daily_totals AS (
        SELECT t.spend_date AS t_date,
               SUM(ABS(t.amount))::double precision AS t_sum
        FROM public.transactions t
        WHERE t.user_id = v_uid
          AND t.is_spend
          AND t.spend_date BETWEEN week_start AND week_end
        GROUP BY t.spend_date
    ),
    peak_transactions AS (
        SELECT DISTINCT ON (t.spend_date)
            t.spend_date AS t_date,
            COALESCE(t.merchant_name, t.name) AS merchant,
            t.personal_finance_category AS category,
            ABS(t.amount)::double precision AS amount
        FROM public.transactions t
        WHERE t.user_id = v_uid
          AND t.is_spend
          AND t.spend_date BETWEEN week_start AND week_end
        ORDER BY t.spend_date, ABS(t.amount) DESC
    )
    SELECT
        TO_CHAR(d.date_series, 'Dy') AS weekday,
        d.date_series::date AS date_label,
        COALESCE(dt.t_sum, 0.0)::double precision AS total_spent,
        COALESCE(d.date_series::date = peak_date, false) AS is_peak,
        COALESCE(pt.merchant, 'No Spend') AS peak_merchant,
        pt.category AS peak_category,
        COALESCE(pt.amount, 0.0)::double precision AS peak_amount
    FROM
        GENERATE_SERIES(week_start::timestamp, week_end::timestamp, '1 day'::interval) d(date_series)
    LEFT JOIN daily_totals dt ON dt.t_date = d.date_series::date
    LEFT JOIN peak_transactions pt ON pt.t_date = d.date_series::date
    ORDER BY d.date_series ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) TO authenticated;
