-- Fix: weekly windows must start on SUNDAY (US convention), not Monday.
--
-- The prior definition (20260603080001) computed the week with EXTRACT(isodow)
-- and `v_today - (v_dow - 1)`, i.e. the most recent MONDAY. For a US user this is
-- wrong: on a Sunday the week-to-date should reset to just that day, but the
-- Monday-start logic folded the whole prior Mon–Sat into "this week" — so weekly
-- spent / pace / percentage and the week-over-week deltas were all off, and they
-- disagreed with the Swift side (Calendar.bablo, which is locale/Sunday-based).
--
-- Only the week-boundary derivation changes here: switch to EXTRACT(dow)
-- (0=Sun…6=Sat) so v_dow is 1=Sun…7=Sat and v_week_start is the most recent
-- Sunday. days_elapsed_in_week therefore counts from Sunday, matching the pinned
-- Calendar.bablo (firstWeekday = 1). Everything downstream (prev-week MTD-aligned
-- windows) follows from v_week_start unchanged.

DROP FUNCTION IF EXISTS public.get_budget_state(date, text);

CREATE OR REPLACE FUNCTION public.get_budget_state(
  p_as_of        date DEFAULT NULL,
  p_income_basis text DEFAULT 'projected'   -- 'projected' | 'cash_only'
)
RETURNS TABLE (
  pool_total            double precision,
  pool_remaining        double precision,
  daily_pace            double precision,
  weekly_pace           double precision,
  spent_today           double precision,
  spent_week            double precision,
  spent_mtd             double precision,
  prev_day_spent        double precision,
  prev_week_spent       double precision,
  prev_month_spent      double precision,
  effective_income      double precision,
  mandatory             double precision,
  goals_set_aside       double precision,
  net_cash              double precision,
  upcoming_bills        double precision,
  income_basis          text,
  days_in_month         int,
  days_remaining        int,
  days_elapsed_in_week  int,
  known_income          double precision,
  extra_income          double precision
)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_tz   text := public.profile_time_zone_for_user(v_uid);
  v_today date := COALESCE(p_as_of, (now() AT TIME ZONE v_tz)::date);

  -- Month / week boundaries
  v_mstart     date := date_trunc('month', v_today)::date;
  v_dim        int  := EXTRACT(day FROM
                         (date_trunc('month', v_today) + interval '1 month - 1 day'))::int;
  v_dom        int  := EXTRACT(day FROM v_today)::int;
  v_drem       int  := v_dim - v_dom + 1;

  -- US week: Sun = 1 … Sat = 7. daysElapsedInWeek matches Swift Calendar.bablo (Sun-start).
  v_dow        int  := EXTRACT(dow FROM v_today)::int + 1;  -- dow 0=Sun…6=Sat → 1=Sun … 7=Sat
  v_week_start date := v_today - (v_dow - 1);               -- most recent Sunday

  -- MTD-aligned previous-period boundaries
  v_prev_week_same_day  date := v_week_start - 7 + (v_today - v_week_start);
  v_prev_week_start     date := v_week_start - 7;
  v_prev_mstart         date := (date_trunc('month', v_today) - interval '1 month')::date;
  v_prev_month_same_day date := v_prev_mstart + (v_dom - 1);
  v_yesterday           date := v_today - 1;

  -- Profile values
  v_income    numeric;
  v_mandatory numeric;
  v_basis     text;

  -- Income split (reuses get_monthly_income_summary rule)
  v_known     double precision;
  v_extra     double precision;
  v_expected  double precision;
  v_eff       double precision;

  -- Cash and upcoming mandatory bills
  v_cash      double precision;
  v_upcoming  double precision;
  v_goals     double precision := 0;   -- decision 6: deferred

  -- Spend windows
  v_spent_mtd   double precision;
  v_spent_week  double precision;
  v_spent_today double precision;
  v_prev_day    double precision;
  v_prev_week   double precision;
  v_prev_month  double precision;

  -- Pool
  v_total  double precision;
  v_rem    double precision;
BEGIN
  -- ── Profile ──────────────────────────────────────────────────────────────
  SELECT COALESCE(profiles_table.monthly_income, 0),
         COALESCE(profiles_table.monthly_mandatory_expenses, 0),
         COALESCE(profiles_table.income_basis, 'projected')
    INTO v_income, v_mandatory, v_basis
    FROM public.profiles_table
   WHERE profiles_table.id = v_uid;

  v_income := COALESCE(v_income, 0);
  v_mandatory := COALESCE(v_mandatory, 0);
  v_basis := COALESCE(v_basis, 'projected');

  -- Caller can override the stored preference (e.g. preview mode)
  IF p_income_basis IS NOT NULL THEN
    v_basis := p_income_basis;
  END IF;

  -- ── Spend windows ────────────────────────────────────────────────────────
  SELECT
    COALESCE(SUM(CASE WHEN spend_date >= v_mstart    AND spend_date <= v_today THEN ABS(amount) ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN spend_date >= v_week_start AND spend_date <= v_today THEN ABS(amount) ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN spend_date = v_today                                 THEN ABS(amount) ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN spend_date = v_yesterday                             THEN ABS(amount) ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN spend_date >= v_prev_week_start  AND spend_date <= v_prev_week_same_day THEN ABS(amount) ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN spend_date >= v_prev_mstart      AND spend_date <= v_prev_month_same_day THEN ABS(amount) ELSE 0 END), 0)
  INTO v_spent_mtd, v_spent_week, v_spent_today,
       v_prev_day, v_prev_week, v_prev_month
  FROM public.variable_transactions
  WHERE user_id = v_uid
    AND spend_date >= LEAST(v_prev_week_start, v_prev_mstart);

  -- ── Income MTD split (same rule as get_monthly_income_summary) ───────────
  SELECT
    COALESCE(SUM(CASE WHEN is_recurring = true              THEN ABS(amount) ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN is_recurring IS DISTINCT FROM true THEN ABS(amount) ELSE 0 END), 0)
  INTO v_known, v_extra
  FROM public.spendable_income_transactions
  WHERE user_id = v_uid
    AND spend_date >= v_mstart
    AND spend_date <= v_today;

  -- ── Net cash ─────────────────────────────────────────────────────────────
  SELECT balance INTO v_cash FROM public.get_net_cash_balance();

  -- ── Upcoming unpaid mandatory bills (next 14 days, not yet posted) ───────
  SELECT COALESCE(SUM(s.average_amount), 0) INTO v_upcoming
    FROM public.active_mandatory_expense_streams s
   WHERE s.user_id = v_uid
     AND s.predicted_next_date BETWEEN v_today AND (v_today + 14)
     AND NOT EXISTS (
       SELECT 1 FROM public.transactions t
        WHERE t.user_id   = v_uid
          AND t.is_spend  = true
          AND t.spend_date >= v_today - 10
          AND NULLIF(BTRIM(s.merchant_name), '') IS NOT NULL
          AND LOWER(BTRIM(t.merchant_name)) = LOWER(BTRIM(s.merchant_name))
     );

  -- ── Effective income (late-month decay mirrors HeroBudgetCalculator) ─────
  IF v_known < v_income * 0.30 AND v_dom > 15 THEN
    v_expected := v_income *
                  GREATEST(0, 1 - (v_dom - 15)::double precision /
                               NULLIF(v_dim - 15, 0));
  ELSE
    v_expected := v_income;
  END IF;
  v_eff := GREATEST(v_expected, v_known) + v_extra;

  -- ── Pool total & remaining ───────────────────────────────────────────────
  IF v_basis = 'cash_only' THEN
    -- Simple-style: cash − scheduled upcoming bills − goals.
    -- Cash already reflects MTD spend, so no separate subtraction.
    v_total := GREATEST(0, v_cash - v_upcoming - v_goals);
    v_rem   := v_total;
  ELSE
    -- Projected (default): income-discretionary model.
    v_total := GREATEST(0, v_eff - v_mandatory::double precision - v_goals);
    v_rem   := v_total - v_spent_mtd;
  END IF;

  -- ── Return ───────────────────────────────────────────────────────────────
  RETURN QUERY SELECT
    v_total,
    v_rem,
    -- daily_pace: floors at $0 when overspent; never negative
    GREATEST(0, v_rem) / NULLIF(v_drem, 0),
    -- weekly_pace: same pool at weekly cadence; caps at pool_remaining near month-end
    LEAST(GREATEST(0, v_rem),
          GREATEST(0, v_rem) / NULLIF(v_drem, 0) * 7),
    v_spent_today,
    v_spent_week,
    v_spent_mtd,
    v_prev_day,
    v_prev_week,
    v_prev_month,
    v_eff,
    v_mandatory::double precision,
    v_goals,
    v_cash,
    v_upcoming,
    v_basis,
    v_dim,
    v_drem,
    v_dow,   -- day-of-week (1=Sun…7=Sat) = days elapsed in week
    v_known,
    v_extra;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_budget_state(date, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_budget_state(date, text) TO authenticated;
