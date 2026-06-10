-- Generalize Coach missions beyond the hardcoded "3-day coffee cap".
--
-- The original slice (20260607035232) shipped one mission type, coffee_cap, with auto-progress
-- already computed from variable_transactions (a day "passes" when matched spend stays under the
-- daily cap — no manual check-in). That engine is sound and reused as-is; this migration only
-- widens it to two more types so a mission can target whatever the user's biggest discretionary
-- leak actually is (see the Spend Trajectory engine, get_spend_trajectory):
--
--   • category_cap — keep a chosen FlexibleSpendingCategory under a daily cap for N days.
--   • no_spend     — N days with zero discretionary spend at all.
--
-- coffee_cap stays valid (back-compat with the existing client + tests).

-- ── 1. Allow the new mission types ──────────────────────────────────────────
ALTER TABLE public.coach_missions_table
  DROP CONSTRAINT IF EXISTS coach_missions_table_mission_type_check;
ALTER TABLE public.coach_missions_table
  ADD CONSTRAINT coach_missions_table_mission_type_check
  CHECK (mission_type IN ('coffee_cap', 'category_cap', 'no_spend'));

-- ── 2. Plaid category → FlexibleSpendingCategory raw value ───────────────────
-- KEEP IN SYNC with ios/Bablo/Bablo/Model/FlexibleSpendingCategory+PlaidMapping.swift
-- (FlexibleSpendingCategory.map). The category_cap matcher needs this same bucketing in SQL to
-- aggregate auto-progress server-side; the iOS client remains the source of truth for display.
CREATE OR REPLACE FUNCTION public.flexible_category_for(
  p_primary TEXT,
  p_sub TEXT
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    -- Subcategory keywords win (shared primaries: coffee & groceries both sit under FOOD_AND_DRINK)
    WHEN UPPER(COALESCE(p_sub, '')) LIKE '%COFFEE%'       THEN 'coffee_runs'
    WHEN UPPER(COALESCE(p_sub, '')) LIKE '%GROCER%'       THEN 'groceries'
    WHEN UPPER(COALESCE(p_primary, '')) LIKE 'FOOD_AND_DRINK%'      THEN 'eats_out'
    WHEN UPPER(COALESCE(p_primary, '')) LIKE 'ENTERTAINMENT%'       THEN 'fun'
    WHEN UPPER(COALESCE(p_primary, '')) LIKE 'GENERAL_MERCHANDISE%' THEN 'shopping'
    WHEN UPPER(COALESCE(p_primary, '')) LIKE 'HOME_IMPROVEMENT%'    THEN 'shopping'
    WHEN UPPER(COALESCE(p_primary, '')) LIKE 'TRANSPORTATION%'      THEN 'getting_around'
    WHEN UPPER(COALESCE(p_primary, '')) LIKE 'PERSONAL_CARE%'       THEN 'self_care'
    WHEN UPPER(COALESCE(p_primary, '')) LIKE 'MEDICAL%'             THEN 'self_care'
    WHEN UPPER(COALESCE(p_primary, '')) LIKE 'TRAVEL%'              THEN 'travel'
    ELSE NULL
  END;
$$;

-- ── 3. Extend the auto-progress matcher ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.coach_mission_matches(
  p_mission_type TEXT,
  p_target_match TEXT,
  p_name TEXT,
  p_merchant_name TEXT,
  p_personal_finance_category TEXT,
  p_personal_finance_subcategory TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_mission_type = 'coffee_cap' THEN
      COALESCE(p_personal_finance_subcategory, '') = 'FOOD_AND_DRINK_COFFEE'
      OR (
        COALESCE(p_personal_finance_category, '') = 'FOOD_AND_DRINK'
        AND LOWER(
          COALESCE(p_name, '') || ' ' ||
          COALESCE(p_merchant_name, '')
        ) LIKE ANY (ARRAY[
          '%coffee%',
          '%cafe%',
          '%café%',
          '%starbucks%',
          '%philz%',
          '%blue bottle%',
          '%peet%'
        ])
      )
    WHEN p_mission_type = 'category_cap' THEN
      public.flexible_category_for(
        p_personal_finance_category,
        p_personal_finance_subcategory
      ) = p_target_match
    -- no_spend caps ALL discretionary spend: every variable txn counts toward the (zero) cap.
    WHEN p_mission_type = 'no_spend' THEN
      TRUE
    ELSE FALSE
  END;
$$;

-- ── 4. Generalize start_coach_mission ───────────────────────────────────────
-- New optional params (target match / title / icon / duration) are appended so the existing
-- 4-arg named call from the iOS client still resolves against the defaults.
DROP FUNCTION IF EXISTS public.start_coach_mission(TEXT, INTEGER, NUMERIC, NUMERIC);

CREATE OR REPLACE FUNCTION public.start_coach_mission(
  p_mission_type TEXT DEFAULT 'category_cap',
  p_target_goal_id INTEGER DEFAULT NULL,
  p_projected_savings NUMERIC DEFAULT 24,
  p_daily_cap NUMERIC DEFAULT 0,
  p_target_match TEXT DEFAULT 'coffee_runs',
  p_title TEXT DEFAULT NULL,
  p_icon TEXT DEFAULT NULL,
  p_duration_days INTEGER DEFAULT 3
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := (SELECT auth.uid());
  v_existing_id BIGINT;
  v_mission_id BIGINT;
  v_days INTEGER := GREATEST(1, COALESCE(p_duration_days, 3));
  v_match TEXT;
  v_title TEXT;
  v_icon TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_mission_type NOT IN ('coffee_cap', 'category_cap', 'no_spend') THEN
    RAISE EXCEPTION 'Unsupported coach mission type: %', p_mission_type;
  END IF;

  IF p_target_goal_id IS NOT NULL THEN
    PERFORM 1
    FROM public.savings_goals_table g
    WHERE g.id = p_target_goal_id
      AND g.user_id = v_user_id
      AND g.is_active = TRUE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Target goal does not belong to the current user';
    END IF;
  END IF;

  -- One active mission per type (matches the existing partial unique index).
  SELECT id
  INTO v_existing_id
  FROM public.coach_missions_table
  WHERE user_id = v_user_id
    AND mission_type = p_mission_type
    AND status = 'active'
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    RETURN public.coach_mission_to_json(v_existing_id);
  END IF;

  -- Resolve match / title / icon, deriving sensible defaults per type when the client omits them.
  v_match := CASE
    WHEN p_mission_type = 'no_spend' THEN ''
    ELSE COALESCE(NULLIF(BTRIM(p_target_match), ''), 'coffee_runs')
  END;

  v_title := COALESCE(NULLIF(BTRIM(p_title), ''), CASE p_mission_type
    WHEN 'no_spend'   THEN v_days || '-day no-spend'
    WHEN 'coffee_cap' THEN v_days || '-day coffee cap'
    ELSE                   v_days || '-day ' || REPLACE(v_match, '_', ' ') || ' cap'
  END);

  v_icon := COALESCE(NULLIF(BTRIM(p_icon), ''), CASE p_mission_type
    WHEN 'no_spend'   THEN '🚫'
    WHEN 'coffee_cap' THEN '☕'
    ELSE                   '🎯'
  END);

  INSERT INTO public.coach_missions_table (
    user_id,
    mission_type,
    title,
    icon,
    target_match,
    target_goal_id,
    start_date,
    end_date,
    daily_cap,
    projected_savings,
    status
  )
  VALUES (
    v_user_id,
    p_mission_type,
    v_title,
    v_icon,
    v_match,
    p_target_goal_id,
    CURRENT_DATE,
    CURRENT_DATE + (v_days - 1),
    GREATEST(0, p_daily_cap),
    GREATEST(0, p_projected_savings),
    'active'
  )
  RETURNING id INTO v_mission_id;

  RETURN public.coach_mission_to_json(v_mission_id);
END;
$$;

-- ── 5. Grants ───────────────────────────────────────────────────────────────
REVOKE EXECUTE ON FUNCTION public.flexible_category_for(TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.flexible_category_for(TEXT, TEXT) FROM anon;
GRANT  EXECUTE ON FUNCTION public.flexible_category_for(TEXT, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.start_coach_mission(TEXT, INTEGER, NUMERIC, NUMERIC, TEXT, TEXT, TEXT, INTEGER) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.start_coach_mission(TEXT, INTEGER, NUMERIC, NUMERIC, TEXT, TEXT, TEXT, INTEGER) FROM anon;
GRANT  EXECUTE ON FUNCTION public.start_coach_mission(TEXT, INTEGER, NUMERIC, NUMERIC, TEXT, TEXT, TEXT, INTEGER) TO authenticated;
