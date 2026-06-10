-- Spend Trajectory engine (deterministic core of the Coach revamp).
--
-- Today every safe-to-spend surface treats the rest of the month as a blank slate. In
-- reality a user's habits are a freight train already in motion: on Jun 9 with $500 spent at
-- Amazon and a $3,000/mo history, the "$2,000 safe" the naive pool reports is a fiction — the
-- habit alone will eat most of it. This function projects month-end discretionary burn so the
-- Coach can show the HONEST cushion (poolRemaining − projected future habit burn).
--
-- Design (see docs/coach-revamp-plan.md):
--   • Pure SQL, NO LLM — the numbers are computed here; the model only narrates them later.
--   • Sourced ONLY from variable_transactions (the layer-2 discretionary view), per the spend-
--     classification rules in CLAUDE.md. NEVER raw is_spend — that would mix in bills/obligations
--     and over-project by orders of magnitude (a single month's wires can be ~$96k).
--   • Returns raw (primary, subcategory) aggregates and lets the iOS client regroup with the
--     SAME FlexibleSpendingCategory mapping the rest of the app uses (one source of truth).
--   • Projection itself (max(MTD, trailing_avg)) is done per-bucket on the client after
--     regrouping — projecting then summing sub-pairs would not equal projecting the bucket.
--
-- TRANSFER_OUT (external/spousal-support wires) is EXCLUDED here: it is real variable spend and
-- correctly sits in variable_transactions, but it is lumpy and uncoachable as a daily *habit*, so
-- projecting it as a recurring trend would distort the cushion. It is already subtracted from the
-- pool via spent_mtd; we simply don't forecast future wires. (Matches the obligation handling in
-- gemini-coach-insights.)
--
-- Trailing window = the 3 full calendar months before the current month. The monthly average for
-- each (primary, subcategory) pair = its trailing total ÷ the number of distinct calendar months
-- in that window that had ANY discretionary activity (min 1). Dividing by a global month count
-- keeps the per-pair averages summable into a correct per-bucket average on the client; a category
-- that appeared in only some months is conservatively under-projected, which is the safe direction.

CREATE OR REPLACE FUNCTION public.get_spend_trajectory(
  p_as_of date DEFAULT NULL
)
RETURNS TABLE (
  primary_category      text,
  subcategory           text,
  mtd_spent             double precision,
  trailing_avg_monthly  double precision,
  txn_count_mtd         int
)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
DECLARE
  v_uid          uuid := auth.uid();
  v_tz           text := public.profile_time_zone_for_user(v_uid);
  v_today        date := COALESCE(p_as_of, (now() AT TIME ZONE v_tz)::date);
  v_mstart       date := date_trunc('month', v_today)::date;
  v_trail_start  date := (date_trunc('month', v_today) - interval '3 months')::date;
  v_trail_end    date := v_mstart - 1;       -- last day of the previous month
  v_trail_months int;
BEGIN
  -- Distinct calendar months with discretionary activity in the trailing window (min 1, so the
  -- division below is always defined and never inflates the average for sparse-history users).
  SELECT GREATEST(1, COUNT(DISTINCT date_trunc('month', vt.spend_date)))
    INTO v_trail_months
    FROM public.variable_transactions vt
   WHERE vt.user_id = v_uid
     AND vt.personal_finance_category IS DISTINCT FROM 'TRANSFER_OUT'
     AND vt.spend_date >= v_trail_start
     AND vt.spend_date <= v_trail_end;

  RETURN QUERY
  SELECT
    COALESCE(vt.personal_finance_category, 'UNKNOWN') AS primary_category,
    vt.personal_finance_subcategory                   AS subcategory,
    COALESCE(SUM(CASE WHEN vt.spend_date >= v_mstart AND vt.spend_date <= v_today
                      THEN ABS(vt.amount) ELSE 0 END), 0)::double precision AS mtd_spent,
    (COALESCE(SUM(CASE WHEN vt.spend_date >= v_trail_start AND vt.spend_date <= v_trail_end
                       THEN ABS(vt.amount) ELSE 0 END), 0)
       / v_trail_months)::double precision AS trailing_avg_monthly,
    COUNT(*) FILTER (WHERE vt.spend_date >= v_mstart AND vt.spend_date <= v_today)::int AS txn_count_mtd
  FROM public.variable_transactions vt
  WHERE vt.user_id = v_uid
    AND vt.personal_finance_category IS DISTINCT FROM 'TRANSFER_OUT'
    AND vt.spend_date >= v_trail_start
    AND vt.spend_date <= v_today
  GROUP BY vt.personal_finance_category, vt.personal_finance_subcategory
  HAVING SUM(CASE WHEN vt.spend_date >= v_mstart    AND vt.spend_date <= v_today   THEN ABS(vt.amount) ELSE 0 END) > 0
      OR SUM(CASE WHEN vt.spend_date >= v_trail_start AND vt.spend_date <= v_trail_end THEN ABS(vt.amount) ELSE 0 END) > 0;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_spend_trajectory(date) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_spend_trajectory(date) TO authenticated;
