-- Finish the deterministic Coach revamp foundation:
--   1. Add explicit mission READY output plus server-backed dismiss/cancel actions.
--   2. Materialize monthly discretionary spend rollups so get_spend_trajectory no longer
--      groups the layered variable_transactions view on every Coach tab open.

-- ── Coach mission lifecycle ────────────────────────────────────────────────
ALTER TABLE public.coach_missions_table
  DROP CONSTRAINT IF EXISTS coach_missions_table_status_check;

ALTER TABLE public.coach_missions_table
  ADD CONSTRAINT coach_missions_table_status_check
  CHECK (status IN ('active', 'ready', 'completed', 'dismissed', 'cancelled'));

CREATE OR REPLACE FUNCTION public.coach_mission_to_json(p_mission_id BIGINT)
RETURNS JSONB
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
  WITH mission AS (
    SELECT m.*, g.name AS goal_name
    FROM public.coach_missions_table m
    LEFT JOIN public.savings_goals_table g
      ON g.id = m.target_goal_id
     AND g.user_id = m.user_id
    WHERE m.id = p_mission_id
      AND m.user_id = (SELECT auth.uid())
  ),
  stats AS (
    SELECT
      m.id,
      GREATEST(1, (m.end_date - m.start_date + 1))::INTEGER AS total_days,
      COALESCE((
        SELECT COUNT(*)::INTEGER
        FROM generate_series(
          m.start_date,
          LEAST(CURRENT_DATE, m.end_date),
          INTERVAL '1 day'
        ) AS d(day)
        WHERE COALESCE((
          SELECT SUM(ABS(vt.amount))
          FROM public.variable_transactions vt
          WHERE vt.user_id = m.user_id
            AND vt.spend_date = d.day::DATE
            AND public.coach_mission_matches(
              m.mission_type,
              m.target_match,
              vt.name,
              vt.merchant_name,
              vt.personal_finance_category,
              vt.personal_finance_subcategory
            )
        ), 0) <= m.daily_cap
      ), 0)::INTEGER AS completed_days
    FROM mission m
  ),
  resolved AS (
    SELECT
      m.*,
      s.total_days,
      CASE
        WHEN m.status = 'completed' THEN s.total_days
        ELSE LEAST(s.completed_days, s.total_days)
      END AS completed_days,
      CASE
        WHEN m.status = 'active' AND LEAST(s.completed_days, s.total_days) >= s.total_days
          THEN 'ready'
        ELSE m.status
      END AS display_status
    FROM mission m
    JOIN stats s ON s.id = m.id
  )
  SELECT jsonb_build_object(
    'id', r.id,
    'user_id', r.user_id,
    'mission_type', r.mission_type,
    'title', r.title,
    'icon', r.icon,
    'target_goal_id', r.target_goal_id,
    'goal_name', r.goal_name,
    'start_date', r.start_date,
    'end_date', r.end_date,
    'projected_savings', r.projected_savings,
    'actual_savings', r.actual_savings,
    'status', r.display_status,
    'completed_days', r.completed_days,
    'total_days', r.total_days,
    'created_at', r.created_at,
    'updated_at', r.updated_at
  )
  FROM resolved r;
$$;

CREATE OR REPLACE FUNCTION public.complete_coach_mission(
  p_mission_id BIGINT,
  p_actual_savings NUMERIC DEFAULT NULL,
  p_stash BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := (SELECT auth.uid());
  v_mission public.coach_missions_table%ROWTYPE;
  v_actual NUMERIC;
  v_deposit JSONB := NULL;
  v_state JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT *
  INTO v_mission
  FROM public.coach_missions_table
  WHERE id = p_mission_id
    AND user_id = v_user_id
    AND status IN ('active', 'ready')
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active coach mission not found';
  END IF;

  v_state := public.coach_mission_to_json(v_mission.id);

  IF COALESCE((v_state->>'completed_days')::INTEGER, 0) < COALESCE((v_state->>'total_days')::INTEGER, 1) THEN
    RAISE EXCEPTION 'Coach mission is not ready to complete';
  END IF;

  v_actual := GREATEST(0, COALESCE(p_actual_savings, v_mission.projected_savings));

  UPDATE public.coach_missions_table
  SET
    status = 'completed',
    actual_savings = v_actual,
    completed_at = NOW()
  WHERE id = v_mission.id;

  IF p_stash AND v_mission.target_goal_id IS NOT NULL AND v_actual > 0 THEN
    INSERT INTO public.savings_deposits_table (
      goal_id,
      user_id,
      amount,
      deposit_date
    )
    VALUES (
      v_mission.target_goal_id,
      v_user_id,
      v_actual,
      CURRENT_DATE
    )
    RETURNING jsonb_build_object(
      'id', id,
      'goal_id', goal_id,
      'user_id', user_id,
      'amount', amount,
      'deposit_date', deposit_date,
      'created_at', created_at
    )
    INTO v_deposit;
  END IF;

  RETURN jsonb_build_object(
    'mission', public.coach_mission_to_json(v_mission.id),
    'deposit', v_deposit
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_coach_mission(p_mission_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := (SELECT auth.uid());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.coach_missions_table
  SET status = 'cancelled'
  WHERE id = p_mission_id
    AND user_id = v_user_id
    AND status IN ('active', 'ready');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active coach mission not found';
  END IF;

  RETURN public.coach_mission_to_json(p_mission_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.dismiss_coach_mission(p_mission_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := (SELECT auth.uid());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.coach_missions_table
  SET status = 'dismissed'
  WHERE id = p_mission_id
    AND user_id = v_user_id
    AND status IN ('active', 'ready');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Coach mission not found';
  END IF;

  RETURN public.coach_mission_to_json(p_mission_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cancel_coach_mission(BIGINT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.dismiss_coach_mission(BIGINT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_coach_mission(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dismiss_coach_mission(BIGINT) TO authenticated;

-- ── Spend rollups ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.spend_rollup (
  user_id UUID NOT NULL REFERENCES public.profiles_table(id) ON DELETE CASCADE,
  month DATE NOT NULL,
  dimension TEXT NOT NULL,
  dimension_key TEXT NOT NULL,
  primary_category TEXT,
  subcategory TEXT,
  total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  txn_count INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, month, dimension, dimension_key),
  CONSTRAINT spend_rollup_month_is_first CHECK (month = date_trunc('month', month)::date),
  CONSTRAINT spend_rollup_supported_dimension CHECK (dimension IN ('plaid_category', 'merchant')),
  CONSTRAINT spend_rollup_non_negative CHECK (total >= 0 AND txn_count >= 0)
);

ALTER TABLE public.spend_rollup ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own spend rollups"
  ON public.spend_rollup;
CREATE POLICY "Users can view their own spend rollups"
  ON public.spend_rollup
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

GRANT SELECT ON public.spend_rollup TO authenticated;

CREATE INDEX IF NOT EXISTS idx_spend_rollup_user_month_dimension
  ON public.spend_rollup(user_id, month, dimension);

CREATE OR REPLACE FUNCTION public.refresh_spend_rollup_month(
  p_user_id UUID,
  p_month DATE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_month DATE := date_trunc('month', p_month)::date;
BEGIN
  IF p_user_id IS NULL OR p_month IS NULL THEN
    RETURN;
  END IF;

  DELETE FROM public.spend_rollup
  WHERE user_id = p_user_id
    AND month = v_month;

  INSERT INTO public.spend_rollup (
    user_id,
    month,
    dimension,
    dimension_key,
    primary_category,
    subcategory,
    total,
    txn_count,
    updated_at
  )
  SELECT
    vt.user_id,
    v_month,
    'plaid_category',
    COALESCE(vt.personal_finance_category, 'UNKNOWN') || '|' || COALESCE(vt.personal_finance_subcategory, ''),
    COALESCE(vt.personal_finance_category, 'UNKNOWN'),
    vt.personal_finance_subcategory,
    ROUND(SUM(ABS(vt.amount))::NUMERIC, 2),
    COUNT(*)::INTEGER,
    NOW()
  FROM public.variable_transactions vt
  WHERE vt.user_id = p_user_id
    AND vt.personal_finance_category IS DISTINCT FROM 'TRANSFER_OUT'
    AND vt.spend_date >= v_month
    AND vt.spend_date < (v_month + INTERVAL '1 month')::date
  GROUP BY vt.user_id, vt.personal_finance_category, vt.personal_finance_subcategory
  HAVING SUM(ABS(vt.amount)) > 0;

  INSERT INTO public.spend_rollup (
    user_id,
    month,
    dimension,
    dimension_key,
    primary_category,
    subcategory,
    total,
    txn_count,
    updated_at
  )
  SELECT
    vt.user_id,
    v_month,
    'merchant',
    LOWER(BTRIM(COALESCE(NULLIF(vt.merchant_name, ''), vt.name, 'Unknown'))),
    NULL,
    NULL,
    ROUND(SUM(ABS(vt.amount))::NUMERIC, 2),
    COUNT(*)::INTEGER,
    NOW()
  FROM public.variable_transactions vt
  WHERE vt.user_id = p_user_id
    AND vt.personal_finance_category IS DISTINCT FROM 'TRANSFER_OUT'
    AND vt.spend_date >= v_month
    AND vt.spend_date < (v_month + INTERVAL '1 month')::date
  GROUP BY vt.user_id, LOWER(BTRIM(COALESCE(NULLIF(vt.merchant_name, ''), vt.name, 'Unknown')))
  HAVING SUM(ABS(vt.amount)) > 0;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.refresh_spend_rollup_month(UUID, DATE) FROM PUBLIC, anon, authenticated;

-- Backfill existing discretionary rollups once when the migration is applied.
INSERT INTO public.spend_rollup (
  user_id,
  month,
  dimension,
  dimension_key,
  primary_category,
  subcategory,
  total,
  txn_count,
  updated_at
)
SELECT
  vt.user_id,
  date_trunc('month', vt.spend_date)::date,
  'plaid_category',
  COALESCE(vt.personal_finance_category, 'UNKNOWN') || '|' || COALESCE(vt.personal_finance_subcategory, ''),
  COALESCE(vt.personal_finance_category, 'UNKNOWN'),
  vt.personal_finance_subcategory,
  ROUND(SUM(ABS(vt.amount))::NUMERIC, 2),
  COUNT(*)::INTEGER,
  NOW()
FROM public.variable_transactions vt
WHERE vt.personal_finance_category IS DISTINCT FROM 'TRANSFER_OUT'
  AND vt.spend_date IS NOT NULL
GROUP BY vt.user_id, date_trunc('month', vt.spend_date)::date, vt.personal_finance_category, vt.personal_finance_subcategory
ON CONFLICT (user_id, month, dimension, dimension_key)
DO UPDATE SET
  primary_category = EXCLUDED.primary_category,
  subcategory = EXCLUDED.subcategory,
  total = EXCLUDED.total,
  txn_count = EXCLUDED.txn_count,
  updated_at = NOW();

INSERT INTO public.spend_rollup (
  user_id,
  month,
  dimension,
  dimension_key,
  primary_category,
  subcategory,
  total,
  txn_count,
  updated_at
)
SELECT
  vt.user_id,
  date_trunc('month', vt.spend_date)::date,
  'merchant',
  LOWER(BTRIM(COALESCE(NULLIF(vt.merchant_name, ''), vt.name, 'Unknown'))),
  NULL,
  NULL,
  ROUND(SUM(ABS(vt.amount))::NUMERIC, 2),
  COUNT(*)::INTEGER,
  NOW()
FROM public.variable_transactions vt
WHERE vt.personal_finance_category IS DISTINCT FROM 'TRANSFER_OUT'
  AND vt.spend_date IS NOT NULL
GROUP BY vt.user_id, date_trunc('month', vt.spend_date)::date, LOWER(BTRIM(COALESCE(NULLIF(vt.merchant_name, ''), vt.name, 'Unknown')))
ON CONFLICT (user_id, month, dimension, dimension_key)
DO UPDATE SET
  total = EXCLUDED.total,
  txn_count = EXCLUDED.txn_count,
  updated_at = NOW();

CREATE OR REPLACE FUNCTION public.refresh_spend_rollup_from_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_month DATE;
  v_new_month DATE;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') AND OLD.user_id IS NOT NULL THEN
    v_old_month := date_trunc('month', COALESCE(OLD.spend_date, OLD.date))::date;
    PERFORM public.refresh_spend_rollup_month(OLD.user_id, v_old_month);
  END IF;

  IF TG_OP IN ('INSERT', 'UPDATE') AND NEW.user_id IS NOT NULL THEN
    v_new_month := date_trunc('month', COALESCE(NEW.spend_date, NEW.date))::date;
    IF TG_OP <> 'UPDATE'
       OR OLD.user_id IS DISTINCT FROM NEW.user_id
       OR v_old_month IS DISTINCT FROM v_new_month THEN
      PERFORM public.refresh_spend_rollup_month(NEW.user_id, v_new_month);
    END IF;
  END IF;

  RETURN NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.refresh_spend_rollup_from_transaction() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS refresh_spend_rollup_after_transaction_change
  ON public.transactions_table;
CREATE TRIGGER refresh_spend_rollup_after_transaction_change
  AFTER INSERT OR UPDATE OR DELETE
  ON public.transactions_table
  FOR EACH ROW
  EXECUTE FUNCTION public.refresh_spend_rollup_from_transaction();

CREATE OR REPLACE FUNCTION public.get_spend_trajectory(
  p_as_of DATE DEFAULT NULL
)
RETURNS TABLE (
  primary_category      TEXT,
  subcategory           TEXT,
  mtd_spent             DOUBLE PRECISION,
  trailing_avg_monthly  DOUBLE PRECISION,
  txn_count_mtd         INT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid          UUID := auth.uid();
  v_tz           TEXT := public.profile_time_zone_for_user(v_uid);
  v_today        DATE := COALESCE(p_as_of, (NOW() AT TIME ZONE v_tz)::DATE);
  v_mstart       DATE := date_trunc('month', v_today)::DATE;
  v_trail_start  DATE := (date_trunc('month', v_today) - INTERVAL '3 months')::DATE;
  v_trail_end    DATE := v_mstart - 1;
  v_trail_months INT;
BEGIN
  SELECT GREATEST(1, COUNT(DISTINCT sr.month))
    INTO v_trail_months
    FROM public.spend_rollup sr
   WHERE sr.user_id = v_uid
     AND sr.dimension = 'plaid_category'
     AND sr.month >= v_trail_start
     AND sr.month <= v_trail_end
     AND sr.total > 0;

  RETURN QUERY
  SELECT
    sr.primary_category,
    sr.subcategory,
    COALESCE(SUM(CASE WHEN sr.month = v_mstart THEN sr.total ELSE 0 END), 0)::DOUBLE PRECISION AS mtd_spent,
    (COALESCE(SUM(CASE WHEN sr.month >= v_trail_start AND sr.month <= v_trail_end THEN sr.total ELSE 0 END), 0)
      / v_trail_months)::DOUBLE PRECISION AS trailing_avg_monthly,
    COALESCE(SUM(CASE WHEN sr.month = v_mstart THEN sr.txn_count ELSE 0 END), 0)::INT AS txn_count_mtd
  FROM public.spend_rollup sr
  WHERE sr.user_id = v_uid
    AND sr.dimension = 'plaid_category'
    AND sr.month >= v_trail_start
    AND sr.month <= v_mstart
  GROUP BY sr.primary_category, sr.subcategory
  HAVING SUM(CASE WHEN sr.month = v_mstart THEN sr.total ELSE 0 END) > 0
      OR SUM(CASE WHEN sr.month >= v_trail_start AND sr.month <= v_trail_end THEN sr.total ELSE 0 END) > 0;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_spend_trajectory(DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_spend_trajectory(DATE) TO authenticated;
