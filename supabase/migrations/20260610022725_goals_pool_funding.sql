-- Goals × Pool integration — G1: auto-stash (Mode B) schema + summary
-- See docs/goals-pool-integration-proposal.md (Appendix A, ticket G1).
--
-- Adds the funding model to savings_goals_table and teaches get_goals_summary to
-- report a *projected* current amount that accrues the monthly contribution over time,
-- so a goal can fund itself without the manual "Log savings" button.
--
-- NOTE: get_goals_summary is recreated from its LATEST deployed definition
-- (20260531055702_fix_goals_and_energy_null.sql) per the recreate-from-latest rule —
-- the only changes are the displayed_current accrual + surfacing monthly_contribution.

-- 1. Funding-model columns -------------------------------------------------------
--    funding_mode 'auto_stash' (default, Mode B) reserves monthly_contribution from the
--    discretionary pool; 'linked' (Mode A, Phase 2) will back the goal with an account
--    balance. linked_account_id is unused until Phase 2.
ALTER TABLE public.savings_goals_table
  ADD COLUMN IF NOT EXISTS funding_mode TEXT NOT NULL DEFAULT 'auto_stash'
    CHECK (funding_mode IN ('auto_stash', 'linked')),
  ADD COLUMN IF NOT EXISTS monthly_contribution NUMERIC(28,2) NOT NULL DEFAULT 0
    CHECK (monthly_contribution >= 0),
  ADD COLUMN IF NOT EXISTS contribution_started_on DATE,
  ADD COLUMN IF NOT EXISTS linked_account_id INTEGER
    REFERENCES public.accounts_table(id) ON DELETE SET NULL;

-- 2. Anchor the accrual clock automatically --------------------------------------
--    Keep the client dumb: whenever a goal has a positive contribution but no start
--    date yet, stamp it CURRENT_DATE. Re-enabling a paused (0) contribution that still
--    carries an old start date is left as-is (acceptable for G1).
CREATE OR REPLACE FUNCTION public.set_goal_contribution_start()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.monthly_contribution > 0 AND NEW.contribution_started_on IS NULL THEN
    NEW.contribution_started_on := CURRENT_DATE;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_goal_contribution_start ON public.savings_goals_table;
CREATE TRIGGER trigger_goal_contribution_start
BEFORE INSERT OR UPDATE ON public.savings_goals_table
FOR EACH ROW EXECUTE FUNCTION public.set_goal_contribution_start();

-- 3. Scheduled-accrual helper ----------------------------------------------------
--    Whole months elapsed since the contribution was set, times the monthly amount.
--    age() yields completed months (e.g. started the 15th, today the 10th next month = 0),
--    so a goal accrues one contribution per full month, never a partial slice.
CREATE OR REPLACE FUNCTION public.goal_scheduled_accrued(
  p_monthly_contribution NUMERIC,
  p_started_on DATE
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
AS $$
  SELECT CASE
    WHEN p_monthly_contribution IS NULL OR p_monthly_contribution <= 0
         OR p_started_on IS NULL OR p_started_on > CURRENT_DATE
      THEN 0::NUMERIC
    ELSE GREATEST(0,
      EXTRACT(YEAR  FROM age(CURRENT_DATE, p_started_on)) * 12
    + EXTRACT(MONTH FROM age(CURRENT_DATE, p_started_on))
    )::NUMERIC * p_monthly_contribution
  END;
$$;

GRANT EXECUTE ON FUNCTION public.goal_scheduled_accrued(NUMERIC, DATE) TO authenticated;

-- 4. get_goals_summary — add projected displayed_current + monthly_contribution -----
--    displayed_current = LEAST(target, stored_current_amount + scheduled_accrued)
--    scheduled_accrued = whole months elapsed since contribution_started_on * monthly_contribution
--    (formulaic projection, no cron; Mode A is the balance-exact version later).
DROP FUNCTION IF EXISTS public.get_goals_summary();

CREATE OR REPLACE FUNCTION public.get_goals_summary()
RETURNS JSON
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_total_stashed NUMERIC := 0;
  v_total_target  NUMERIC := 0;
  v_funded_pct    NUMERIC := 0;
  v_goal_count    INTEGER := 0;
  v_this_month    NUMERIC := 0;
  v_depository_balance NUMERIC := 0;
  v_vault_covered BOOLEAN := true;
  v_goals         JSON;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Vault totals use the *projected* displayed_current so the stashed figure matches
  -- what the per-goal cards (and the pool reservation) show.
  SELECT
    COALESCE(SUM(
      LEAST(
        g.target_amount,
        g.current_amount + public.goal_scheduled_accrued(
          g.monthly_contribution, g.contribution_started_on)
      )
    ), 0),
    COALESCE(SUM(g.target_amount), 0),
    COUNT(*)
  INTO v_total_stashed, v_total_target, v_goal_count
  FROM public.savings_goals_table g
  WHERE g.user_id = v_user_id
    AND g.is_active = true;

  IF v_total_target > 0 THEN
    v_funded_pct := ROUND((v_total_stashed / v_total_target) * 100, 1);
  END IF;

  SELECT COALESCE(SUM(d.amount), 0)
  INTO v_this_month
  FROM public.savings_deposits_table d
  WHERE d.user_id = v_user_id
    AND d.deposit_date >= DATE_TRUNC('month', CURRENT_DATE);

  SELECT COALESCE(SUM(a.current_balance), 0)
  INTO v_depository_balance
  FROM public.accounts_table a
  INNER JOIN public.items_table i ON a.item_id = i.id
  WHERE i.user_id = v_user_id
    AND a.type = 'depository'
    AND a.hidden = false;

  v_vault_covered := v_total_stashed <= v_depository_balance;

  SELECT json_agg(goal_data ORDER BY g.priority ASC, g.created_at ASC)
  INTO v_goals
  FROM public.savings_goals_table g
  CROSS JOIN LATERAL (
    -- Projected current amount: stored (lumps + legacy deposits) + scheduled accrual.
    SELECT LEAST(
      g.target_amount,
      g.current_amount + public.goal_scheduled_accrued(
        g.monthly_contribution, g.contribution_started_on)
    ) AS displayed_current
  ) proj
  CROSS JOIN LATERAL (
    SELECT COALESCE(
      SUM(d.amount) / NULLIF(
        GREATEST(
          (CURRENT_DATE - MIN(d.deposit_date)) / 7.0,
          1
        ), 0
      ),
      0
    ) AS weekly_rate
    FROM public.savings_deposits_table d
    WHERE d.goal_id = g.id
      AND d.deposit_date >= CURRENT_DATE - INTERVAL '56 days'
  ) rate_calc
  CROSS JOIN LATERAL (
    SELECT COALESCE(SUM(d2.amount), 0) AS goal_this_month
    FROM public.savings_deposits_table d2
    WHERE d2.goal_id = g.id
      AND d2.deposit_date >= DATE_TRUNC('month', CURRENT_DATE)
  ) month_calc
  CROSS JOIN LATERAL (
    SELECT
      ROUND(LEAST(proj.displayed_current / NULLIF(g.target_amount, 0) * 100, 100), 1) AS pct,
      CASE
        WHEN proj.displayed_current >= g.target_amount THEN NULL
        -- Prefer the contribution-derived ETA when auto-stashing; fall back to deposit rate.
        WHEN g.monthly_contribution > 0 THEN
          CURRENT_DATE + (CEIL((g.target_amount - proj.displayed_current)
                               / g.monthly_contribution) * 30)::INTEGER
        WHEN rate_calc.weekly_rate > 0 THEN
          CURRENT_DATE + (CEIL((g.target_amount - proj.displayed_current)
                               / rate_calc.weekly_rate) * 7)::INTEGER
        ELSE NULL
      END AS eta_date,
      CASE
        WHEN proj.displayed_current >= g.target_amount THEN 'funded'
        WHEN g.monthly_contribution <= 0 AND rate_calc.weekly_rate <= 0 THEN 'at risk'
        WHEN ROUND(proj.displayed_current / NULLIF(g.target_amount, 0) * 100, 1) >= 75 THEN 'almost'
        WHEN g.eta_date IS NOT NULL AND g.eta_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'on track'
        WHEN ROUND(proj.displayed_current / NULLIF(g.target_amount, 0) * 100, 1) >= 25 THEN 'on track'
        ELSE 'building'
      END AS status_label
  ) derived
  CROSS JOIN LATERAL (
    SELECT json_build_object(
      'id',                   g.id,
      'name',                 g.name,
      'category_icon',        g.category_icon,
      'target_amount',        g.target_amount,
      'current_amount',       proj.displayed_current,
      'eta_date',             derived.eta_date,
      'is_active',            g.is_active,
      'color',                g.color,
      'priority',             g.priority,
      'pct',                  derived.pct,
      'weekly_rate',          ROUND(rate_calc.weekly_rate, 0),
      'this_month',           month_calc.goal_this_month,
      'status_label',         derived.status_label,
      'funding_mode',         g.funding_mode,
      'monthly_contribution', g.monthly_contribution
    ) AS goal_data
  ) packed
  WHERE g.user_id = v_user_id
    AND g.is_active = true;

  RETURN json_build_object(
    'total_stashed',       v_total_stashed,
    'total_target',        v_total_target,
    'funded_pct',          v_funded_pct,
    'goal_count',          v_goal_count,
    'this_month',          v_this_month,
    'depository_balance',  v_depository_balance,
    'vault_covered',       v_vault_covered,
    'goals',               COALESCE(v_goals, '[]'::JSON)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_goals_summary() TO authenticated;
