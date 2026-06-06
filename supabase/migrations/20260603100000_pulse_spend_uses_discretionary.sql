-- Make the Pulse "Swing" report spend the SAME discretionary number as the hero,
-- Money-Left breakdown, and Cushion — i.e. variable_transactions.
--
-- Background: "spent this month" was showing different totals on different screens
-- because four surfaces each used a different spend definition:
--   * Liquid Hero / Money-Left / Cushion  → variable_transactions (discretionary)   [correct]
--   * Pulse damage report headline         → get_daily_transaction_stats (is_spend, TOTAL)
--   * Pulse category breakdown             → transactions WHERE is_spend (TOTAL)  [iOS]
--   * Pulse day-by-day energy              → transactions_table, amount>0 not TRANSFER (yet another)
-- For one user that read as $8,595 (total, incl. rent + mandatory bills) on Pulse vs
-- $5,340 (discretionary) on the hero/Money-Left. The mandatory bills are already
-- subtracted as their own line in the pool, so the discretionary layer is the single
-- canonical "spent". This points the two Pulse RPCs at variable_transactions; the iOS
-- category-breakdown fetch is switched in the same change.

-- ── Damage report headline / net ─────────────────────────────────────────────
-- total_out now sums discretionary spend (variable_transactions). total_in stays the
-- income layer (is_income on the transactions view) so the net In−Out still makes sense.
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
    SELECT v.spend_date AS d, SUM(ABS(v.amount))::double precision AS amt
    FROM public.variable_transactions v
    WHERE v.user_id = auth.uid()
      AND v.spend_date BETWEEN start_date AND end_date
    GROUP BY v.spend_date
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

-- ── Day-by-day energy bars ───────────────────────────────────────────────────
-- Rebased on variable_transactions (discretionary) using the canonical spend_date, and
-- switched to SECURITY INVOKER to match the other analytics RPCs (RLS scopes rows; the
-- explicit user_id filter is kept as belt-and-suspenders).
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
    -- Highest discretionary-spend day in the range.
    SELECT v.spend_date INTO peak_date
    FROM public.variable_transactions v
    WHERE v.user_id = v_uid
      AND v.spend_date BETWEEN week_start AND week_end
    GROUP BY v.spend_date
    ORDER BY SUM(ABS(v.amount)) DESC
    LIMIT 1;

    RETURN QUERY
    WITH daily_totals AS (
        SELECT v.spend_date AS t_date,
               SUM(ABS(v.amount))::double precision AS t_sum
        FROM public.variable_transactions v
        WHERE v.user_id = v_uid
          AND v.spend_date BETWEEN week_start AND week_end
        GROUP BY v.spend_date
    ),
    peak_transactions AS (
        SELECT DISTINCT ON (v.spend_date)
            v.spend_date AS t_date,
            COALESCE(v.merchant_name, v.name) AS merchant,
            v.personal_finance_category AS category,
            ABS(v.amount)::double precision AS amount
        FROM public.variable_transactions v
        WHERE v.user_id = v_uid
          AND v.spend_date BETWEEN week_start AND week_end
        ORDER BY v.spend_date, ABS(v.amount) DESC
    )
    SELECT
        TO_CHAR(d.date_series, 'Dy') AS weekday,
        d.date_series::date AS date_label,
        COALESCE(dt.t_sum, 0.0)::double precision AS total_spent,
        -- COALESCE so a week with no discretionary spend (peak_date NULL) yields false,
        -- not NULL — the client decodes is_peak as a non-optional Bool.
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
