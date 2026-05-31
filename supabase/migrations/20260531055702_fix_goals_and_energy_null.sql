-- Fix DATE_PART bug in get_goals_summary by using direct days subtraction (which yields integer)
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
    COALESCE(SUM(g.current_amount), 0),
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
      ROUND(LEAST(g.current_amount / NULLIF(g.target_amount, 0) * 100, 100), 1) AS pct,
      CASE
        WHEN g.current_amount >= g.target_amount THEN NULL
        WHEN rate_calc.weekly_rate > 0 THEN
          CURRENT_DATE + (CEIL((g.target_amount - g.current_amount) / rate_calc.weekly_rate) * 7)::INTEGER
        ELSE NULL
      END AS eta_date,
      CASE
        WHEN g.current_amount >= g.target_amount THEN 'funded'
        WHEN rate_calc.weekly_rate <= 0 THEN 'at risk'
        WHEN ROUND(g.current_amount / NULLIF(g.target_amount, 0) * 100, 1) >= 75 THEN 'almost'
        WHEN g.eta_date IS NOT NULL AND g.eta_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'on track'
        WHEN ROUND(g.current_amount / NULLIF(g.target_amount, 0) * 100, 1) >= 25 THEN 'on track'
        ELSE 'building'
      END AS status_label
  ) derived
  CROSS JOIN LATERAL (
    SELECT json_build_object(
      'id',             g.id,
      'name',           g.name,
      'category_icon',  g.category_icon,
      'target_amount',  g.target_amount,
      'current_amount', g.current_amount,
      'eta_date',       derived.eta_date,
      'is_active',      g.is_active,
      'color',          g.color,
      'priority',       g.priority,
      'pct',            derived.pct,
      'weekly_rate',    ROUND(rate_calc.weekly_rate, 0),
      'this_month',     month_calc.goal_this_month,
      'status_label',   derived.status_label
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


-- Fix nullable peak day decoding issue in get_pulse_weekly_energy by defaulting to false instead of null
DROP FUNCTION IF EXISTS public.get_pulse_weekly_energy(date, date);

CREATE OR REPLACE FUNCTION public.get_pulse_weekly_energy(week_start DATE, week_end DATE)
RETURNS TABLE (weekday TEXT, date_label DATE, total_spent DOUBLE PRECISION,
               is_peak BOOLEAN, peak_merchant TEXT, peak_category TEXT, peak_amount DOUBLE PRECISION)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
DECLARE peak_date DATE;
BEGIN
    SELECT t.spend_date INTO peak_date
    FROM public.transactions t
    WHERE t.user_id = auth.uid()
      AND t.spend_date BETWEEN week_start AND week_end
      AND t.is_spend
    GROUP BY t.spend_date
    ORDER BY SUM(t.amount) DESC LIMIT 1;

    RETURN QUERY
    WITH daily_totals AS (
        SELECT t.spend_date AS t_date, SUM(t.amount)::double precision AS t_sum
        FROM public.transactions t
        WHERE t.user_id = auth.uid()
          AND t.spend_date BETWEEN week_start AND week_end
          AND t.is_spend
        GROUP BY t.spend_date
    ),
    peak_transactions AS (
        SELECT DISTINCT ON (t.spend_date)
            t.spend_date AS t_date,
            COALESCE(t.merchant_name, t.name) AS merchant,
            t.personal_finance_category AS category,
            t.amount::double precision AS amount
        FROM public.transactions t
        WHERE t.user_id = auth.uid()
          AND t.spend_date BETWEEN week_start AND week_end
          AND t.is_spend
        ORDER BY t.spend_date, t.amount DESC
    )
    SELECT TO_CHAR(d.date_series, 'Dy'), d.date_series::date,
           COALESCE(dt.t_sum, 0.0)::double precision, COALESCE(d.date_series::date = peak_date, FALSE),
           COALESCE(pt.merchant, 'No Spend'), pt.category, COALESCE(pt.amount, 0.0)::double precision
    FROM GENERATE_SERIES(week_start::timestamp, week_end::timestamp, '1 day'::interval) d(date_series)
    LEFT JOIN daily_totals dt ON dt.t_date = d.date_series::date
    LEFT JOIN peak_transactions pt ON pt.t_date = d.date_series::date
    ORDER BY d.date_series ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) TO authenticated;
