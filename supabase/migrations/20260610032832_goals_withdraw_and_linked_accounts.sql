-- Goals × Pool integration — finish G3/G4.
--
-- G3: allow explicit withdrawals from stored goal progress through a bounded RPC.
-- G4: make linked/account-backed goals use the linked account balance for progress and
-- exclude those accounts from net cash so safe-to-spend is not inflated.

-- Allow negative movement rows for withdrawals while still rejecting zero-value noise.
ALTER TABLE public.savings_deposits_table
  DROP CONSTRAINT IF EXISTS savings_deposits_table_amount_check;

ALTER TABLE public.savings_deposits_table
  DROP CONSTRAINT IF EXISTS savings_deposits_amount_nonzero;

ALTER TABLE public.savings_deposits_table
  ADD CONSTRAINT savings_deposits_amount_nonzero CHECK (amount <> 0);

CREATE OR REPLACE FUNCTION public.withdraw_from_goal(
  p_goal_id integer,
  p_amount numeric
)
RETURNS public.savings_deposits_table
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_goal public.savings_goals_table%ROWTYPE;
  v_amount numeric(28,2);
  v_withdrawal public.savings_deposits_table%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_amount := ROUND(COALESCE(p_amount, 0), 2);
  IF v_amount <= 0 THEN
    RAISE EXCEPTION 'Withdrawal amount must be positive';
  END IF;

  SELECT *
    INTO v_goal
    FROM public.savings_goals_table
   WHERE id = p_goal_id
     AND user_id = v_uid
     AND is_active = true
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Goal not found';
  END IF;

  IF v_amount > v_goal.current_amount THEN
    RAISE EXCEPTION 'Withdrawal exceeds stored goal balance';
  END IF;

  INSERT INTO public.savings_deposits_table (goal_id, user_id, amount, deposit_date)
  VALUES (p_goal_id, v_uid, -v_amount, CURRENT_DATE)
  RETURNING * INTO v_withdrawal;

  RETURN v_withdrawal;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.withdraw_from_goal(integer, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.withdraw_from_goal(integer, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_net_cash_balance()
RETURNS TABLE (
    balance           double precision,
    iso_currency_code text,
    as_of             text
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(
            CASE
                WHEN a.type ILIKE 'depository' THEN  a.current_balance::double precision
                WHEN a.type ILIKE 'credit'     THEN -a.current_balance::double precision
                ELSE 0::double precision
            END
        ), 0)::double precision                                         AS balance,
        'USD'::text                                                     AS iso_currency_code,
        TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS as_of
    FROM public.accounts a
    WHERE a.user_id = auth.uid()
      AND a.hidden = false
      AND NOT EXISTS (
        SELECT 1
          FROM public.savings_goals_table g
         WHERE g.user_id = auth.uid()
           AND g.is_active = true
           AND g.funding_mode = 'linked'
           AND g.linked_account_id = a.id
      );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_net_cash_balance() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_net_cash_balance() TO authenticated;

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

  SELECT
    COALESCE(SUM(
      LEAST(
        g.target_amount,
        CASE
          WHEN g.funding_mode = 'linked' AND linked_account.id IS NOT NULL THEN
            linked_account.current_balance
          ELSE
            g.current_amount + public.goal_scheduled_accrued(
              g.monthly_contribution, g.contribution_started_on)
        END
      )
    ), 0),
    COALESCE(SUM(g.target_amount), 0),
    COUNT(*)
  INTO v_total_stashed, v_total_target, v_goal_count
  FROM public.savings_goals_table g
  LEFT JOIN public.accounts linked_account
    ON linked_account.id = g.linked_account_id
   AND linked_account.user_id = v_user_id
   AND linked_account.hidden = false
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
  LEFT JOIN public.accounts linked_account
    ON linked_account.id = g.linked_account_id
   AND linked_account.user_id = v_user_id
   AND linked_account.hidden = false
  CROSS JOIN LATERAL (
    SELECT LEAST(
      g.target_amount,
      CASE
        WHEN g.funding_mode = 'linked' AND linked_account.id IS NOT NULL THEN
          linked_account.current_balance
        ELSE
          g.current_amount + public.goal_scheduled_accrued(
            g.monthly_contribution, g.contribution_started_on)
      END
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
        WHEN g.funding_mode = 'linked' THEN NULL
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
        WHEN g.funding_mode = 'linked' AND linked_account.id IS NOT NULL THEN 'linked'
        WHEN g.funding_mode = 'linked' THEN 'needs account'
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
      'monthly_contribution', g.monthly_contribution,
      'linked_account_id',    g.linked_account_id
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
