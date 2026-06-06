-- Count a received paycheck as KNOWN (recurring) income even when Plaid hasn't linked it
-- to its recurring stream yet — most importantly while it is still PENDING.
--
-- Problem: the income split (known vs extra) is driven solely by transactions_table.is_recurring,
-- which only flips true once a Plaid junction link exists (recurring_stream_transactions_table).
-- That never happens for a pending paycheck (pending rows never get is_recurring=true), and it
-- never happens at all for income streams whose junction is empty. Consequence: a paycheck that
-- has clearly landed counts as "extra" (one-off) income, so it ADDS on top of projected salary
-- instead of REDUCING the still-expected salary. The "How we got this" breakdown then shows a
-- received paycheck as extra AND projects a full month of salary as still expected — double
-- counting roughly one paycheck.
--
-- Fix (symmetric with the mandatory-expense merchant safety net used by variable_transactions):
-- an income transaction counts as a paycheck — and therefore KNOWN income — when it matches an
-- active income stream, regardless of pending/linked status. The match key (chosen 2026-06-05):
--   1. ACH originator id parsed from the free-text name (e.g. "...ID: J770493581"), matched
--      against the same id parsed from the stream description. This is the only key reliably
--      present in BOTH pending and settled paycheck names AND the stream — merchant_name is null
--      on payroll rows, and the PFC subcategory (INCOME_WAGES) is identical for paychecks,
--      brokerage credits and HSA reimbursements, so neither can separate them.
--   2. Fallback when the transaction name has no parseable id: amount within 10% of the
--      stream's average_amount. (A windfall like a $6,464 brokerage credit is >10% off the
--      $5,495 salary, so it stays "extra"; a $5,495.36 vs $5,495.35 paycheck still matches.)
--
-- The match is exposed as a new is_paycheck column on spendable_income_transactions and consumed
-- by get_budget_state and get_monthly_income_summary (known = is_recurring OR is_paycheck).

-- ── Helper: extract the ACH originator id from a transaction name / stream description ──────────
-- Grabs the first "ID: XXXX" token (PPD ID / ORIG ID / ACH ID / …). NULL when none present.
CREATE OR REPLACE FUNCTION public.extract_ach_id(p_name text)
RETURNS text
LANGUAGE sql IMMUTABLE
AS $$
  SELECT NULLIF((regexp_match(COALESCE(p_name, ''), 'ID:\s*([A-Za-z0-9]+)'))[1], '');
$$;

-- ── Income view gains an is_paycheck flag (matches an active income stream) ─────────────────────
CREATE OR REPLACE VIEW public.spendable_income_transactions
WITH (security_invoker = true)
AS
SELECT
  t.*,
  EXISTS (
    SELECT 1
    FROM public.recurring_streams_table s
    WHERE s.user_id = t.user_id
      AND s.type = 'income'
      AND s.is_active = true
      AND COALESCE(s.is_excluded, false) = false
      AND s.status IS DISTINCT FROM 'TOMBSTONED'
      AND (
        -- (1) originator-id match: same ACH id in the txn name and the stream description
        (
          public.extract_ach_id(t.name) IS NOT NULL
          AND public.extract_ach_id(t.name) = public.extract_ach_id(s.description)
        )
        -- (2) amount fallback: only when the txn name carries no parseable id
        OR (
          public.extract_ach_id(t.name) IS NULL
          AND s.average_amount > 0
          AND ABS(ABS(t.amount) - s.average_amount) <= 0.10 * s.average_amount
        )
      )
  ) AS is_paycheck
FROM public.transactions t
WHERE t.amount < 0
  AND COALESCE(t.type, '') NOT IN ('credit', 'loan')
  AND t.personal_finance_category = 'INCOME';

GRANT SELECT ON public.spendable_income_transactions TO authenticated;

-- ── get_monthly_income_summary: known now includes is_paycheck ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_monthly_income_summary(p_start date, p_end date)
RETURNS TABLE (
    known_income double precision,
    extra_income double precision
)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(CASE WHEN t.is_recurring = true OR t.is_paycheck = true
                     THEN ABS(t.amount) ELSE 0 END), 0)::double precision AS known_income,
        COALESCE(SUM(CASE WHEN COALESCE(t.is_recurring, false) = false
                           AND COALESCE(t.is_paycheck, false) = false
                     THEN ABS(t.amount) ELSE 0 END), 0)::double precision AS extra_income
    FROM public.spendable_income_transactions t
    WHERE t.user_id    = auth.uid()
      AND t.spend_date BETWEEN p_start AND p_end;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_monthly_income_summary(date, date) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_monthly_income_summary(date, date) TO authenticated;

-- ── get_budget_state: same known/extra rule (only the income-split block changed) ───────────────
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

  -- ISO week: Mon = 1 … Sun = 7. daysElapsedInWeek matches Swift Calendar.bablo (Mon-start).
  v_dow        int  := EXTRACT(isodow FROM v_today)::int;  -- 1=Mon … 7=Sun
  v_week_start date := v_today - (v_dow - 1);             -- most recent Monday

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
  -- known = matched to a recurring stream (is_recurring) OR matched to an active income
  -- stream by originator id / amount (is_paycheck) — so a received paycheck counts as
  -- salary even while pending/unlinked, instead of inflating the pool as "extra".
  SELECT
    COALESCE(SUM(CASE WHEN is_recurring = true OR is_paycheck = true
                 THEN ABS(amount) ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN COALESCE(is_recurring, false) = false
                       AND COALESCE(is_paycheck, false) = false
                 THEN ABS(amount) ELSE 0 END), 0)
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
    v_dow,   -- ISO day-of-week (1=Mon…7=Sun) = days elapsed in week
    v_known,
    v_extra;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_budget_state(date, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_budget_state(date, text) TO authenticated;
