-- =============================================================================
-- COMPLETE PRODUCTION DATABASE SCHEMA
-- Project: https://supabase.com/dashboard/project/teuyzmreoyganejfvquk/sql/new
-- =============================================================================
--
-- This is a SCHEMA SNAPSHOT of the production database (tables, views, functions,
-- triggers, RLS policies, indexes, grants) — NOT a migration-by-migration log.
-- Run the whole script in the Supabase Dashboard SQL Editor to stand up a fresh
-- database that matches production.
--
-- HOW TO REGENERATE after applying new migrations / pushing schema changes:
--     supabase db dump --schema public -f /tmp/prod_schema_dump.sql
-- then replace everything between the two markers below with that dump, keeping the
-- "auth.users signup trigger" section at the end (a public-schema dump cannot see
-- objects in the auth schema, so that one trigger is maintained here by hand).
--
-- The source of truth for incremental changes is supabase/migrations/. This file is
-- a derived, full-state convenience for from-scratch setup.
-- =============================================================================

-- ===== BEGIN GENERATED SCHEMA (supabase db dump --schema public) =============



SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."compute_transaction_spend_date"("tx_date" "date", "tx_authorized_date" "date", "tx_authorized_datetime" timestamp with time zone, "tx_pending" boolean, "tx_created_at" timestamp with time zone, "local_timezone" "text" DEFAULT 'UTC'::"text") RETURNS "date"
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
  SELECT
    CASE
      WHEN tx_authorized_datetime IS NOT NULL
        THEN (tx_authorized_datetime AT TIME ZONE local_timezone)::date
      WHEN COALESCE(tx_authorized_date, tx_date) IS NULL
        THEN NULL
      WHEN COALESCE(tx_pending, false)
        AND tx_created_at IS NOT NULL
        AND COALESCE(tx_authorized_date, tx_date) > (tx_created_at AT TIME ZONE local_timezone)::date
        THEN (tx_created_at AT TIME ZONE local_timezone)::date
      ELSE COALESCE(tx_authorized_date, tx_date)
    END;
$$;


ALTER FUNCTION "public"."compute_transaction_spend_date"("tx_date" "date", "tx_authorized_date" "date", "tx_authorized_datetime" timestamp with time zone, "tx_pending" boolean, "tx_created_at" timestamp with time zone, "local_timezone" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_daily_transaction_stats"("start_date" "date", "end_date" "date") RETURNS TABLE("date" "date", "total_in" double precision, "total_out" double precision)
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.spend_date::date AS date,
    COALESCE(SUM(CASE
      WHEN t.is_income THEN ABS(t.amount)
      ELSE 0
    END), 0)::double precision AS total_in,
    COALESCE(SUM(CASE
      WHEN t.is_spend THEN t.amount
      ELSE 0
    END), 0)::double precision AS total_out
  FROM public.transactions t
  WHERE t.user_id = auth.uid()
    AND t.spend_date BETWEEN start_date AND end_date
    AND (t.is_spend OR t.is_income)
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;


ALTER FUNCTION "public"."get_daily_transaction_stats"("start_date" "date", "end_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_goals_summary"() RETURNS json
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "public"."get_goals_summary"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_monthly_income_summary"("p_start" "date", "p_end" "date") RETURNS TABLE("known_income" double precision, "extra_income" double precision)
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(CASE WHEN t.is_recurring = true
                     THEN ABS(t.amount) ELSE 0 END), 0)::double precision AS known_income,
        COALESCE(SUM(CASE WHEN t.is_recurring IS DISTINCT FROM true
                     THEN ABS(t.amount) ELSE 0 END), 0)::double precision AS extra_income
    FROM public.spendable_income_transactions t
    WHERE t.user_id    = auth.uid()
      AND t.spend_date BETWEEN p_start AND p_end;
END;
$$;


ALTER FUNCTION "public"."get_monthly_income_summary"("p_start" "date", "p_end" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_monthly_transaction_stats"("start_date" "date", "end_date" "date") RETURNS TABLE("year" double precision, "month" double precision, "total_in" double precision, "total_out" double precision)
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    EXTRACT(YEAR FROM t.spend_date)::double precision,
    EXTRACT(MONTH FROM t.spend_date)::double precision,
    COALESCE(SUM(CASE WHEN t.is_income THEN ABS(t.amount) ELSE 0 END), 0)::double precision,
    COALESCE(SUM(CASE WHEN t.is_spend  THEN t.amount       ELSE 0 END), 0)::double precision
  FROM public.transactions t
  WHERE t.user_id = auth.uid()
    AND t.spend_date BETWEEN start_date AND end_date
    AND (t.is_spend OR t.is_income)
  GROUP BY 1, 2
  ORDER BY 1 DESC, 2 DESC;
END;
$$;


ALTER FUNCTION "public"."get_monthly_transaction_stats"("start_date" "date", "end_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_net_cash_balance"() RETURNS TABLE("balance" double precision, "iso_currency_code" "text", "as_of" "text")
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
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
        ), 0)::double precision                                     AS balance,
        'USD'::text                                                 AS iso_currency_code,
        TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS as_of
    FROM public.accounts a
    WHERE a.user_id = auth.uid()
      AND a.hidden = false;
END;
$$;


ALTER FUNCTION "public"."get_net_cash_balance"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_period_spend_comparison"("p_prev_week_start" "date", "p_prev_week_same_day_end" "date", "p_prev_month_start" "date", "p_prev_month_same_day_end" "date", "p_current_week_start" "date", "p_today" "date") RETURNS TABLE("prev_week" double precision, "prev_month" double precision, "current_week" double precision, "today" double precision)
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(CASE
            WHEN t.spend_date BETWEEN p_prev_week_start AND p_prev_week_same_day_end
            THEN ABS(t.amount) ELSE 0 END), 0)::double precision  AS prev_week,
        COALESCE(SUM(CASE
            WHEN t.spend_date BETWEEN p_prev_month_start AND p_prev_month_same_day_end
            THEN ABS(t.amount) ELSE 0 END), 0)::double precision  AS prev_month,
        COALESCE(SUM(CASE
            WHEN t.spend_date BETWEEN p_current_week_start AND p_today
            THEN ABS(t.amount) ELSE 0 END), 0)::double precision  AS current_week,
        COALESCE(SUM(CASE
            WHEN t.spend_date = p_today
            THEN ABS(t.amount) ELSE 0 END), 0)::double precision  AS today
    FROM public.variable_transactions t
    WHERE t.user_id    = auth.uid()
      AND t.spend_date >= LEAST(p_prev_week_start, p_prev_month_start);
END;
$$;


ALTER FUNCTION "public"."get_period_spend_comparison"("p_prev_week_start" "date", "p_prev_week_same_day_end" "date", "p_prev_month_start" "date", "p_prev_month_same_day_end" "date", "p_current_week_start" "date", "p_today" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_pulse_top_merchants"("start_date" "date", "end_date" "date", "lim" integer DEFAULT 5) RETURNS TABLE("merchant_name" "text", "total_spent" double precision, "transaction_count" bigint, "personal_finance_category" "text")
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN QUERY
    SELECT COALESCE(t.merchant_name, t.name), SUM(t.amount)::double precision,
           COUNT(*)::bigint, MIN(t.personal_finance_category)
    FROM public.transactions t
    WHERE t.user_id = auth.uid()
      AND t.spend_date BETWEEN start_date AND end_date
      AND t.is_spend
    GROUP BY COALESCE(t.merchant_name, t.name)
    ORDER BY SUM(t.amount) DESC LIMIT lim;
END;
$$;


ALTER FUNCTION "public"."get_pulse_top_merchants"("start_date" "date", "end_date" "date", "lim" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_pulse_weekly_energy"("week_start" "date", "week_end" "date") RETURNS TABLE("weekday" "text", "date_label" "date", "total_spent" double precision, "is_peak" boolean, "peak_merchant" "text", "peak_category" "text", "peak_amount" double precision)
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."get_pulse_weekly_energy"("week_start" "date", "week_end" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_spending_breakdown"("p_start" "date", "p_end" "date") RETURNS TABLE("category" "text", "total_spent" double precision, "transaction_count" bigint, "percent_of_total" double precision)
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN QUERY
    WITH category_totals AS (
        SELECT
            COALESCE(t.personal_finance_category, 'Uncategorized') AS category,
            SUM(ABS(t.amount))::double precision                    AS total_spent,
            COUNT(*)::bigint                                         AS transaction_count
        FROM public.transactions t
        WHERE t.user_id     = auth.uid()
          AND t.spend_date  BETWEEN p_start AND p_end
          AND t.is_spend    = true
        GROUP BY t.personal_finance_category
    ),
    grand_total AS (
        SELECT COALESCE(SUM(ct.total_spent), 0) AS total FROM category_totals ct
    )
    SELECT
        ct.category,
        ct.total_spent,
        ct.transaction_count,
        CASE WHEN gt.total > 0
             THEN (ct.total_spent / gt.total * 100)::double precision
             ELSE 0::double precision
        END AS percent_of_total
    FROM category_totals ct
    CROSS JOIN grand_total gt
    ORDER BY ct.total_spent DESC;
END;
$$;


ALTER FUNCTION "public"."get_spending_breakdown"("p_start" "date", "p_end" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_spending_streak"("p_today" "date" DEFAULT CURRENT_DATE) RETURNS TABLE("current_streak" integer, "max_streak" integer, "last_10_days_status" boolean[])
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
    profile_income NUMERIC(28,2);
    fixed_exp NUMERIC(28,2);
    actual_income NUMERIC(28,2);
    day_income_val NUMERIC(28,2);
    nominal_daily_limit NUMERIC(28,2);
    effective_daily_limit NUMERIC(28,2);
    spent_before_day NUMERIC(28,2);
    month_discretionary NUMERIC(28,2);
    monthly_remaining_before_day NUMERIC(28,2);

    streak_count INT := 0;
    max_streak_count INT := 0;
    temp_streak INT := 0;
    day_idx INT;
    spend_on_day NUMERIC(28,2);
    status_arr BOOLEAN[] := '{}';
    day_date DATE;
    current_streak_set BOOLEAN := FALSE;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.items_table WHERE user_id = (SELECT auth.uid()) AND is_active = TRUE
    ) THEN RETURN; END IF;

    SELECT COALESCE(monthly_income, 0), COALESCE(monthly_mandatory_expenses, 0)
    INTO profile_income, fixed_exp
    FROM public.profiles_table WHERE id = (SELECT auth.uid());

    FOR day_idx IN 0..89 LOOP
        day_date := p_today - day_idx;

        SELECT COALESCE(SUM(ABS(amount)), 0) INTO actual_income
        FROM public.spendable_income_transactions
        WHERE user_id = (SELECT auth.uid())
          AND date >= DATE_TRUNC('month', day_date)::DATE
          AND date <= (DATE_TRUNC('month', day_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

        day_income_val := GREATEST(profile_income, actual_income);
        nominal_daily_limit := (day_income_val - fixed_exp) / 30.0;

        -- Discretionary spend before this day (excludes recurring/fixed obligations).
        SELECT COALESCE(SUM(vt.amount), 0) INTO spent_before_day
        FROM public.variable_transactions vt
        WHERE vt.user_id = (SELECT auth.uid())
          AND vt.spend_date >= DATE_TRUNC('month', day_date)::DATE
          AND vt.spend_date < day_date;

        month_discretionary := GREATEST(0, day_income_val - fixed_exp);
        monthly_remaining_before_day := month_discretionary - spent_before_day;
        effective_daily_limit := GREATEST(0, LEAST(nominal_daily_limit, monthly_remaining_before_day));

        -- Discretionary spend on this day (excludes recurring/fixed obligations).
        SELECT COALESCE(SUM(vt.amount), 0) INTO spend_on_day
        FROM public.variable_transactions vt
        WHERE vt.user_id = (SELECT auth.uid())
          AND vt.spend_date = day_date;

        IF effective_daily_limit > 0 AND spend_on_day <= effective_daily_limit THEN
            temp_streak := temp_streak + 1;
            IF day_idx < 10 THEN status_arr := array_append(status_arr, TRUE); END IF;
        ELSE
            IF NOT current_streak_set THEN streak_count := temp_streak; current_streak_set := TRUE; END IF;
            IF temp_streak > max_streak_count THEN max_streak_count := temp_streak; END IF;
            temp_streak := 0;
            IF day_idx < 10 THEN status_arr := array_append(status_arr, FALSE); END IF;
        END IF;
    END LOOP;

    IF NOT current_streak_set THEN streak_count := temp_streak; END IF;
    IF temp_streak > max_streak_count THEN max_streak_count := temp_streak; END IF;
    RETURN QUERY SELECT streak_count, max_streak_count, status_arr;
END;
$$;


ALTER FUNCTION "public"."get_user_spending_streak"("p_today" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_variable_spend"("p_start" "date", "p_end" "date") RETURNS double precision
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
    result double precision;
BEGIN
    SELECT COALESCE(SUM(ABS(t.amount)), 0)::double precision
    INTO result
    FROM public.variable_transactions t
    WHERE t.user_id    = auth.uid()
      AND t.spend_date BETWEEN p_start AND p_end;
    RETURN result;
END;
$$;


ALTER FUNCTION "public"."get_variable_spend"("p_start" "date", "p_end" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.profiles_table (id, username)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."profile_time_zone_for_user"("profile_user_id" "uuid") RETURNS "text"
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
  SELECT COALESCE(
    (
      SELECT p.time_zone
      FROM public.profiles_table p
      JOIN pg_timezone_names z ON z.name = p.time_zone
      WHERE p.id = profile_user_id
      LIMIT 1
    ),
    'UTC'
  );
$$;


ALTER FUNCTION "public"."profile_time_zone_for_user"("profile_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_transaction_spend_date"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
  profile_timezone text;
BEGIN
  profile_timezone := public.profile_time_zone_for_user(NEW.user_id);

  NEW.spend_date := public.compute_transaction_spend_date(
    NEW.date,
    NEW.authorized_date,
    NEW.authorized_datetime,
    NEW.pending,
    COALESCE(NEW.created_at, now()),
    profile_timezone
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_transaction_spend_date"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_set_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_set_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_goal_current_amount"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.savings_goals_table
        SET current_amount = current_amount + NEW.amount
        WHERE id = NEW.goal_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.savings_goals_table
        SET current_amount = current_amount - OLD.amount
        WHERE id = OLD.goal_id;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_goal_current_amount"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."accounts_table" (
    "id" integer NOT NULL,
    "item_id" integer,
    "plaid_account_id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "mask" "text" NOT NULL,
    "official_name" "text",
    "current_balance" numeric(28,10),
    "available_balance" numeric(28,10),
    "iso_currency_code" "text",
    "unofficial_currency_code" "text",
    "type" "text" NOT NULL,
    "subtype" "text" NOT NULL,
    "hidden" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."accounts_table" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."items_table" (
    "id" integer NOT NULL,
    "user_id" "uuid",
    "bank_name" "text",
    "plaid_access_token" "text" NOT NULL,
    "plaid_item_id" "text" NOT NULL,
    "plaid_institution_id" "text" NOT NULL,
    "status" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "transactions_cursor" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "historical_sync_complete" boolean DEFAULT false,
    "historical_completed_at" timestamp with time zone
);


ALTER TABLE "public"."items_table" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."accounts" WITH ("security_invoker"='true') AS
 SELECT "a"."id",
    "a"."plaid_account_id",
    "a"."item_id",
    "i"."plaid_item_id",
    "i"."user_id",
    "a"."name",
    "a"."mask",
    "a"."official_name",
    "a"."current_balance",
    "a"."available_balance",
    "a"."iso_currency_code",
    "a"."unofficial_currency_code",
    "a"."type",
    "a"."subtype",
    "a"."hidden",
    "a"."created_at",
    "a"."updated_at"
   FROM ("public"."accounts_table" "a"
     LEFT JOIN "public"."items_table" "i" ON (("i"."id" = "a"."item_id")));


ALTER VIEW "public"."accounts" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."accounts_table_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."accounts_table_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."accounts_table_id_seq" OWNED BY "public"."accounts_table"."id";



CREATE TABLE IF NOT EXISTS "public"."institutions_table" (
    "id" integer NOT NULL,
    "institution_id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "primary_color" "text",
    "url" "text",
    "logo" "text",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."institutions_table" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."accounts_with_banks" WITH ("security_invoker"='true') AS
 SELECT "a"."id",
    "a"."item_id",
    "a"."name",
    "a"."mask",
    "a"."official_name",
    "a"."current_balance",
    "a"."available_balance",
    "a"."type",
    "a"."subtype",
    "a"."hidden",
    "a"."plaid_account_id" AS "account_id",
    "a"."iso_currency_code",
    "a"."created_at",
    "a"."updated_at",
    "i"."id" AS "institution_id",
    "i"."name" AS "institution_name",
    "i"."logo" AS "institution_logo",
    "i"."primary_color" AS "institution_color",
    "i"."url" AS "institution_url",
    "it"."user_id"
   FROM (("public"."accounts_table" "a"
     JOIN "public"."items_table" "it" ON (("a"."item_id" = "it"."id")))
     JOIN "public"."institutions_table" "i" ON (("it"."plaid_institution_id" = "i"."institution_id")));


ALTER VIEW "public"."accounts_with_banks" OWNER TO "postgres";


COMMENT ON VIEW "public"."accounts_with_banks" IS 'View that joins accounts with their bank institution information for efficient querying by iOS app';



CREATE TABLE IF NOT EXISTS "public"."recurring_streams_table" (
    "id" integer NOT NULL,
    "user_id" "uuid" NOT NULL,
    "item_id" integer,
    "account_id" integer,
    "plaid_stream_id" "text",
    "description" "text" NOT NULL,
    "merchant_name" "text",
    "personal_finance_category" "text",
    "personal_finance_subcategory" "text",
    "frequency" "text" NOT NULL,
    "average_amount" numeric(28,10) NOT NULL,
    "last_amount" numeric(28,10),
    "monthly_amount" numeric(28,10) NOT NULL,
    "iso_currency_code" "text" DEFAULT 'USD'::"text",
    "type" "text" NOT NULL,
    "status" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "first_date" "date",
    "last_date" "date",
    "predicted_next_date" "date",
    "is_user_modified" boolean DEFAULT false,
    "user_marked_recurring" boolean,
    "is_excluded" boolean DEFAULT false,
    "is_manual" boolean DEFAULT false,
    "match_pattern" "text",
    "last_synced_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "recurring_streams_table_check" CHECK (((("is_manual" = false) AND ("plaid_stream_id" IS NOT NULL)) OR (("is_manual" = true) AND ("match_pattern" IS NOT NULL)))),
    CONSTRAINT "recurring_streams_table_type_check" CHECK (("type" = ANY (ARRAY['income'::"text", 'expense'::"text"])))
);


ALTER TABLE "public"."recurring_streams_table" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."active_mandatory_expense_streams" WITH ("security_invoker"='true') AS
 SELECT "id",
    "user_id",
    "item_id",
    "account_id",
    "plaid_stream_id",
    "description",
    "merchant_name",
    "personal_finance_category",
    "personal_finance_subcategory",
    "frequency",
    "average_amount",
    "last_amount",
    "monthly_amount",
    "iso_currency_code",
    "type",
    "status",
    "is_active",
    "first_date",
    "last_date",
    "predicted_next_date",
    "is_user_modified",
    "user_marked_recurring",
    "is_excluded",
    "is_manual",
    "match_pattern",
    "last_synced_at",
    "created_at",
    "updated_at"
   FROM "public"."recurring_streams_table" "rs"
  WHERE (("type" = 'expense'::"text") AND ("is_active" = true) AND ("is_excluded" = false) AND ("status" <> 'TOMBSTONED'::"text") AND (COALESCE("personal_finance_subcategory", ''::"text") <> 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'::"text") AND (COALESCE("personal_finance_category", ''::"text") <> 'GENERAL_MERCHANDISE'::"text") AND (NOT (("is_manual" = true) AND ("lower"("btrim"("description")) = ANY (ARRAY['rent'::"text", 'rent payment'::"text", 'rent / mortgage'::"text", 'apartment rent'::"text", 'mortgage'::"text", 'mortgage payment'::"text"])) AND (EXISTS ( SELECT 1
           FROM "public"."recurring_streams_table" "auto_rs"
          WHERE (("auto_rs"."user_id" = "rs"."user_id") AND ("auto_rs"."type" = 'expense'::"text") AND ("auto_rs"."is_active" = true) AND ("auto_rs"."is_excluded" = false) AND ("auto_rs"."is_manual" = false) AND ("auto_rs"."status" <> 'TOMBSTONED'::"text") AND (("auto_rs"."personal_finance_subcategory" = ANY (ARRAY['RENT_AND_UTILITIES_RENT'::"text", 'RENT_OR_MORTGAGE'::"text"])) OR ("lower"("btrim"(COALESCE("auto_rs"."merchant_name", ''::"text"))) = ANY (ARRAY['rent'::"text", 'rent payment'::"text", 'rent / mortgage'::"text", 'apartment rent'::"text", 'mortgage'::"text", 'mortgage payment'::"text"])) OR ("lower"("btrim"("auto_rs"."description")) = ANY (ARRAY['rent'::"text", 'rent payment'::"text", 'rent / mortgage'::"text", 'apartment rent'::"text", 'mortgage'::"text", 'mortgage payment'::"text"])))))))));


ALTER VIEW "public"."active_mandatory_expense_streams" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."active_subscription_streams" WITH ("security_invoker"='true') AS
 SELECT "id",
    "user_id",
    "item_id",
    "account_id",
    "plaid_stream_id",
    "description",
    "merchant_name",
    "personal_finance_category",
    "personal_finance_subcategory",
    "frequency",
    "average_amount",
    "last_amount",
    "monthly_amount",
    "iso_currency_code",
    "type",
    "status",
    "is_active",
    "first_date",
    "last_date",
    "predicted_next_date",
    "is_user_modified",
    "user_marked_recurring",
    "is_excluded",
    "is_manual",
    "match_pattern",
    "last_synced_at",
    "created_at",
    "updated_at"
   FROM "public"."recurring_streams_table"
  WHERE (("type" = 'expense'::"text") AND ("is_active" = true) AND ("is_excluded" = false) AND ("status" <> 'TOMBSTONED'::"text") AND (COALESCE("personal_finance_category", ''::"text") <> ALL (ARRAY['RENT_OR_MORTGAGE'::"text", 'RENT_AND_UTILITIES'::"text", 'LOAN_PAYMENTS'::"text"])) AND (COALESCE("personal_finance_subcategory", ''::"text") <> ALL (ARRAY['RENT_AND_UTILITIES_RENT'::"text", 'RENT_OR_MORTGAGE'::"text", 'GENERAL_SERVICES_INSURANCE'::"text", 'GENERAL_SERVICES_AUTOMOTIVE'::"text"])) AND ("lower"("btrim"(COALESCE("merchant_name", ''::"text"))) <> ALL (ARRAY['rent'::"text", 'rent payment'::"text", 'rent / mortgage'::"text", 'apartment rent'::"text", 'mortgage'::"text", 'mortgage payment'::"text"])) AND ("lower"("btrim"("description")) <> ALL (ARRAY['rent'::"text", 'rent payment'::"text", 'rent / mortgage'::"text", 'apartment rent'::"text", 'mortgage'::"text", 'mortgage payment'::"text"])));


ALTER VIEW "public"."active_subscription_streams" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."assets_table" (
    "id" integer NOT NULL,
    "user_id" "uuid",
    "value" numeric(28,2),
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."assets_table" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."assets" WITH ("security_invoker"='true') AS
 SELECT "id",
    "user_id",
    "value",
    "description",
    "created_at",
    "updated_at"
   FROM "public"."assets_table";


ALTER VIEW "public"."assets" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."assets_table_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."assets_table_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."assets_table_id_seq" OWNED BY "public"."assets_table"."id";



CREATE OR REPLACE VIEW "public"."institutions" WITH ("security_invoker"='true') AS
 SELECT "id",
    "institution_id",
    "name",
    "primary_color",
    "url",
    "logo",
    "updated_at"
   FROM "public"."institutions_table";


ALTER VIEW "public"."institutions" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."institutions_table_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."institutions_table_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."institutions_table_id_seq" OWNED BY "public"."institutions_table"."id";



CREATE OR REPLACE VIEW "public"."items" WITH ("security_invoker"='true') AS
 SELECT "id",
    "plaid_item_id",
    "user_id",
    "plaid_access_token",
    "plaid_institution_id",
    "status",
    "created_at",
    "updated_at",
    "transactions_cursor",
    "bank_name"
   FROM "public"."items_table";


ALTER VIEW "public"."items" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."items_table_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."items_table_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."items_table_id_seq" OWNED BY "public"."items_table"."id";



CREATE TABLE IF NOT EXISTS "public"."link_events_table" (
    "id" integer NOT NULL,
    "type" "text" NOT NULL,
    "user_id" "uuid",
    "link_session_id" "text",
    "request_id" "text",
    "error_type" "text",
    "error_code" "text",
    "status" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."link_events_table" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."link_events_table_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."link_events_table_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."link_events_table_id_seq" OWNED BY "public"."link_events_table"."id";



CREATE TABLE IF NOT EXISTS "public"."plaid_api_events_table" (
    "id" integer NOT NULL,
    "item_id" integer,
    "user_id" "uuid",
    "plaid_method" "text" NOT NULL,
    "arguments" "text",
    "request_id" "text",
    "error_type" "text",
    "error_code" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."plaid_api_events_table" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."plaid_api_events_table_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."plaid_api_events_table_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."plaid_api_events_table_id_seq" OWNED BY "public"."plaid_api_events_table"."id";



CREATE TABLE IF NOT EXISTS "public"."profiles_table" (
    "id" "uuid" NOT NULL,
    "username" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "monthly_income" numeric(28,2) DEFAULT 0,
    "monthly_mandatory_expenses" numeric(28,2) DEFAULT 0,
    "tracked_spending_categories" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "first_name" "text",
    "spending_plan_mode" "text" DEFAULT 'safe_to_spend'::"text" NOT NULL,
    "time_zone" "text",
    CONSTRAINT "profiles_table_spending_plan_mode_check" CHECK (("spending_plan_mode" = ANY (ARRAY['safe_to_spend'::"text", 'monthly_plan'::"text"])))
);


ALTER TABLE "public"."profiles_table" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."profiles" WITH ("security_invoker"='true') AS
 SELECT "id",
    "username",
    "monthly_income",
    "monthly_mandatory_expenses",
    "created_at",
    "updated_at",
    "tracked_spending_categories",
    "first_name",
    "spending_plan_mode",
    "time_zone"
   FROM "public"."profiles_table";


ALTER VIEW "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."recurring_stream_transactions_table" (
    "id" integer NOT NULL,
    "stream_id" integer NOT NULL,
    "transaction_id" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."recurring_stream_transactions_table" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."recurring_stream_transactions_table_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."recurring_stream_transactions_table_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."recurring_stream_transactions_table_id_seq" OWNED BY "public"."recurring_stream_transactions_table"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."recurring_streams_table_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."recurring_streams_table_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."recurring_streams_table_id_seq" OWNED BY "public"."recurring_streams_table"."id";



CREATE TABLE IF NOT EXISTS "public"."refresh_jobs" (
    "id" integer NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" NOT NULL,
    "job_type" "text" NOT NULL,
    "job_id" "text",
    "last_refresh_time" timestamp with time zone,
    "next_scheduled_time" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "error_message" "text",
    CONSTRAINT "refresh_jobs_job_type_check" CHECK (("job_type" = ANY (ARRAY['manual'::"text", 'scheduled'::"text"]))),
    CONSTRAINT "refresh_jobs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'completed'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."refresh_jobs" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."refresh_jobs_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."refresh_jobs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."refresh_jobs_id_seq" OWNED BY "public"."refresh_jobs"."id";



CREATE TABLE IF NOT EXISTS "public"."savings_deposits_table" (
    "id" integer NOT NULL,
    "goal_id" integer NOT NULL,
    "user_id" "uuid" NOT NULL,
    "amount" numeric(28,2) NOT NULL,
    "deposit_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "savings_deposits_table_amount_check" CHECK (("amount" > (0)::numeric))
);


ALTER TABLE "public"."savings_deposits_table" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."savings_deposits_table_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."savings_deposits_table_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."savings_deposits_table_id_seq" OWNED BY "public"."savings_deposits_table"."id";



CREATE TABLE IF NOT EXISTS "public"."savings_goals_table" (
    "id" integer NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "target_amount" numeric(28,2) NOT NULL,
    "current_amount" numeric(28,2) DEFAULT 0 NOT NULL,
    "eta_date" "date",
    "category_icon" "text" DEFAULT '✈️'::"text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "color" "text" DEFAULT '#A9F236'::"text" NOT NULL,
    "priority" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "savings_goals_table_current_amount_check" CHECK (("current_amount" >= (0)::numeric)),
    CONSTRAINT "savings_goals_table_target_amount_check" CHECK (("target_amount" > (0)::numeric))
);


ALTER TABLE "public"."savings_goals_table" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."savings_goals_table_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."savings_goals_table_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."savings_goals_table_id_seq" OWNED BY "public"."savings_goals_table"."id";



CREATE TABLE IF NOT EXISTS "public"."transactions_table" (
    "id" integer NOT NULL,
    "account_id" integer,
    "user_id" "uuid",
    "amount" numeric(28,10) NOT NULL,
    "iso_currency_code" "text",
    "date" "date" NOT NULL,
    "authorized_date" "date",
    "name" "text" NOT NULL,
    "merchant_name" "text",
    "logo_url" "text",
    "website" "text",
    "payment_channel" "text",
    "transaction_id" "text" NOT NULL,
    "personal_finance_category" "text",
    "personal_finance_subcategory" "text",
    "pending" boolean NOT NULL,
    "pending_transaction_transaction_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_recurring" boolean DEFAULT false,
    "spend_date" "date",
    "authorized_datetime" timestamp with time zone,
    "datetime" timestamp with time zone
);


ALTER TABLE "public"."transactions_table" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."transactions" WITH ("security_invoker"='true') AS
 SELECT "t"."id",
    "t"."account_id",
    "a"."user_id",
    "a"."plaid_account_id",
    "a"."item_id",
    "a"."plaid_item_id",
    "a"."type",
    "t"."amount",
    "t"."is_recurring",
    "t"."iso_currency_code",
    "t"."date",
    "t"."authorized_date",
    "t"."name",
    "t"."merchant_name",
    "t"."logo_url",
    "t"."website",
    "t"."payment_channel",
    "t"."transaction_id",
    "t"."personal_finance_category",
    "t"."personal_finance_subcategory",
    "t"."pending",
    "t"."pending_transaction_transaction_id",
    "t"."created_at",
    "t"."updated_at",
    "t"."spend_date",
    (("t"."amount" > (0)::numeric) AND (COALESCE("a"."type", ''::"text") !~~* 'investment'::"text") AND ((("t"."personal_finance_category" IS NOT NULL) AND (NOT (("t"."personal_finance_category" = 'TRANSFER_IN'::"text") AND (COALESCE("t"."personal_finance_subcategory", ''::"text") <> 'TRANSFER_IN_ACCOUNT_TRANSFER'::"text"))) AND (NOT (COALESCE("t"."personal_finance_subcategory", ''::"text") = 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'::"text")) AND (NOT (("t"."personal_finance_category" = 'TRANSFER_OUT'::"text") AND (COALESCE("t"."personal_finance_subcategory", ''::"text") <> ALL (ARRAY['TRANSFER_OUT_ACCOUNT_TRANSFER'::"text", 'TRANSFER_OUT_WITHDRAWAL'::"text", 'TRANSFER_OUT_OTHER_TRANSFER_OUT'::"text"])))) AND (NOT (("t"."personal_finance_category" = 'INCOME'::"text") AND (COALESCE("t"."name", ''::"text") ~~* ANY (ARRAY['%transfer%'::"text", '%wire%'::"text", '%reversal%'::"text", '%brokerage%'::"text", '%bkrg%'::"text", '%schwab%'::"text", '%moneylink%'::"text", '%invest%'::"text"]))))) OR (("t"."personal_finance_category" IS NULL) AND ("t"."name" !~~* '%Payment%'::"text") AND ("t"."name" !~~* '%Transfer%'::"text")))) AS "is_spend",
    (("t"."amount" < (0)::numeric) AND (COALESCE("a"."type", ''::"text") !~~* 'credit'::"text") AND (COALESCE("a"."type", ''::"text") !~~* 'loan'::"text") AND (("t"."personal_finance_subcategory" = 'TRANSFER_IN_ACCOUNT_TRANSFER'::"text") OR (("t"."personal_finance_category" = 'INCOME'::"text") AND (NOT (COALESCE("t"."name", ''::"text") ~~* ANY (ARRAY['%transfer%'::"text", '%wire%'::"text", '%reversal%'::"text", '%brokerage%'::"text", '%bkrg%'::"text", '%schwab%'::"text", '%moneylink%'::"text", '%invest%'::"text"])))))) AS "is_income",
    "t"."authorized_datetime",
    "t"."datetime"
   FROM ("public"."transactions_table" "t"
     LEFT JOIN "public"."accounts" "a" ON (("t"."account_id" = "a"."id")));


ALTER VIEW "public"."transactions" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."spendable_income_transactions" WITH ("security_invoker"='true') AS
 SELECT "id",
    "account_id",
    "user_id",
    "plaid_account_id",
    "item_id",
    "plaid_item_id",
    "type",
    "amount",
    "is_recurring",
    "iso_currency_code",
    "date",
    "authorized_date",
    "name",
    "merchant_name",
    "logo_url",
    "website",
    "payment_channel",
    "transaction_id",
    "personal_finance_category",
    "personal_finance_subcategory",
    "pending",
    "pending_transaction_transaction_id",
    "created_at",
    "updated_at",
    "spend_date",
    "is_spend",
    "is_income",
    "authorized_datetime",
    "datetime"
   FROM "public"."transactions" "t"
  WHERE (("amount" < (0)::numeric) AND (COALESCE("type", ''::"text") <> ALL (ARRAY['credit'::"text", 'loan'::"text"])) AND ("personal_finance_category" = 'INCOME'::"text") AND (NOT ((COALESCE("name", ''::"text") ~~* ANY (ARRAY['%transfer%'::"text", '%wire%'::"text", '%reversal%'::"text", '%brokerage%'::"text", '%bkrg%'::"text", '%schwab%'::"text", '%moneylink%'::"text", '%invest%'::"text"])) OR (COALESCE("merchant_name", ''::"text") ~~* ANY (ARRAY['%transfer%'::"text", '%wire%'::"text", '%reversal%'::"text", '%brokerage%'::"text", '%bkrg%'::"text", '%schwab%'::"text", '%moneylink%'::"text", '%invest%'::"text"])))));


ALTER VIEW "public"."spendable_income_transactions" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."transactions_table_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."transactions_table_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."transactions_table_id_seq" OWNED BY "public"."transactions_table"."id";



CREATE OR REPLACE VIEW "public"."variable_transactions" WITH ("security_invoker"='true') AS
 SELECT "id",
    "account_id",
    "user_id",
    "plaid_account_id",
    "item_id",
    "plaid_item_id",
    "type",
    "amount",
    "is_recurring",
    "iso_currency_code",
    "date",
    "authorized_date",
    "name",
    "merchant_name",
    "logo_url",
    "website",
    "payment_channel",
    "transaction_id",
    "personal_finance_category",
    "personal_finance_subcategory",
    "pending",
    "pending_transaction_transaction_id",
    "created_at",
    "updated_at",
    "spend_date",
    "is_spend",
    "is_income",
    "authorized_datetime",
    "datetime"
   FROM "public"."transactions" "t"
  WHERE ("is_spend" AND (("is_recurring" = false) OR ("is_recurring" IS NULL)) AND (NOT (EXISTS ( SELECT 1
           FROM "public"."active_mandatory_expense_streams" "ames"
          WHERE (("ames"."user_id" = "t"."user_id") AND (("ames"."user_marked_recurring" = true) OR ("ames"."user_marked_recurring" IS NULL)) AND (NULLIF("btrim"("ames"."merchant_name"), ''::"text") IS NOT NULL) AND ("lower"("btrim"("t"."merchant_name")) = "lower"("btrim"("ames"."merchant_name"))))))));


ALTER VIEW "public"."variable_transactions" OWNER TO "postgres";


ALTER TABLE ONLY "public"."accounts_table" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."accounts_table_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."assets_table" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."assets_table_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."institutions_table" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."institutions_table_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."items_table" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."items_table_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."link_events_table" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."link_events_table_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."plaid_api_events_table" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."plaid_api_events_table_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."recurring_stream_transactions_table" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."recurring_stream_transactions_table_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."recurring_streams_table" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."recurring_streams_table_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."refresh_jobs" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."refresh_jobs_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."savings_deposits_table" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."savings_deposits_table_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."savings_goals_table" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."savings_goals_table_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."transactions_table" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."transactions_table_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."accounts_table"
    ADD CONSTRAINT "accounts_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."accounts_table"
    ADD CONSTRAINT "accounts_table_plaid_account_id_key" UNIQUE ("plaid_account_id");



ALTER TABLE ONLY "public"."assets_table"
    ADD CONSTRAINT "assets_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."institutions_table"
    ADD CONSTRAINT "institutions_table_institution_id_key" UNIQUE ("institution_id");



ALTER TABLE ONLY "public"."institutions_table"
    ADD CONSTRAINT "institutions_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."items_table"
    ADD CONSTRAINT "items_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."items_table"
    ADD CONSTRAINT "items_table_plaid_access_token_key" UNIQUE ("plaid_access_token");



ALTER TABLE ONLY "public"."items_table"
    ADD CONSTRAINT "items_table_plaid_item_id_key" UNIQUE ("plaid_item_id");



ALTER TABLE ONLY "public"."link_events_table"
    ADD CONSTRAINT "link_events_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."link_events_table"
    ADD CONSTRAINT "link_events_table_request_id_key" UNIQUE ("request_id");



ALTER TABLE ONLY "public"."plaid_api_events_table"
    ADD CONSTRAINT "plaid_api_events_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."plaid_api_events_table"
    ADD CONSTRAINT "plaid_api_events_table_request_id_key" UNIQUE ("request_id");



ALTER TABLE ONLY "public"."profiles_table"
    ADD CONSTRAINT "profiles_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles_table"
    ADD CONSTRAINT "profiles_table_username_key" UNIQUE ("username");



ALTER TABLE ONLY "public"."recurring_stream_transactions_table"
    ADD CONSTRAINT "recurring_stream_transactions_tabl_stream_id_transaction_id_key" UNIQUE ("stream_id", "transaction_id");



ALTER TABLE ONLY "public"."recurring_stream_transactions_table"
    ADD CONSTRAINT "recurring_stream_transactions_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."recurring_streams_table"
    ADD CONSTRAINT "recurring_streams_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."refresh_jobs"
    ADD CONSTRAINT "refresh_jobs_job_id_key" UNIQUE ("job_id");



ALTER TABLE ONLY "public"."refresh_jobs"
    ADD CONSTRAINT "refresh_jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."savings_deposits_table"
    ADD CONSTRAINT "savings_deposits_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."savings_goals_table"
    ADD CONSTRAINT "savings_goals_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transactions_table"
    ADD CONSTRAINT "transactions_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transactions_table"
    ADD CONSTRAINT "transactions_table_transaction_id_key" UNIQUE ("transaction_id");



CREATE INDEX "idx_accounts_item_id" ON "public"."accounts_table" USING "btree" ("item_id");



CREATE INDEX "idx_accounts_plaid_account_id" ON "public"."accounts_table" USING "btree" ("plaid_account_id");



CREATE INDEX "idx_assets_user_id" ON "public"."assets_table" USING "btree" ("user_id");



CREATE INDEX "idx_items_historical_complete" ON "public"."items_table" USING "btree" ("historical_sync_complete");



CREATE INDEX "idx_items_plaid_item_id" ON "public"."items_table" USING "btree" ("plaid_item_id");



CREATE INDEX "idx_items_user_id" ON "public"."items_table" USING "btree" ("user_id");



CREATE INDEX "idx_link_events_user_id" ON "public"."link_events_table" USING "btree" ("user_id");



CREATE INDEX "idx_plaid_api_events_item_id" ON "public"."plaid_api_events_table" USING "btree" ("item_id");



CREATE INDEX "idx_plaid_api_events_user_id" ON "public"."plaid_api_events_table" USING "btree" ("user_id");



CREATE INDEX "idx_recurring_streams_account_id" ON "public"."recurring_streams_table" USING "btree" ("account_id");



CREATE INDEX "idx_recurring_streams_is_manual" ON "public"."recurring_streams_table" USING "btree" ("user_id", "is_manual");



CREATE INDEX "idx_recurring_streams_item_id" ON "public"."recurring_streams_table" USING "btree" ("item_id");



CREATE INDEX "idx_recurring_streams_type" ON "public"."recurring_streams_table" USING "btree" ("user_id", "type", "is_active");



CREATE INDEX "idx_recurring_streams_user_id" ON "public"."recurring_streams_table" USING "btree" ("user_id");



CREATE INDEX "idx_savings_deposits_goal_date" ON "public"."savings_deposits_table" USING "btree" ("goal_id", "deposit_date");



CREATE INDEX "idx_savings_deposits_user_id" ON "public"."savings_deposits_table" USING "btree" ("user_id");



CREATE INDEX "idx_savings_goals_user_id" ON "public"."savings_goals_table" USING "btree" ("user_id");



CREATE INDEX "idx_stream_transactions_stream" ON "public"."recurring_stream_transactions_table" USING "btree" ("stream_id");



CREATE INDEX "idx_stream_transactions_transaction" ON "public"."recurring_stream_transactions_table" USING "btree" ("transaction_id");



CREATE INDEX "idx_stream_tx_lookup" ON "public"."recurring_stream_transactions_table" USING "btree" ("transaction_id", "stream_id");



CREATE INDEX "idx_transactions_account_id" ON "public"."transactions_table" USING "btree" ("account_id");



CREATE INDEX "idx_transactions_non_recurring" ON "public"."transactions_table" USING "btree" ("user_id", "date") WHERE (("is_recurring" = false) OR ("is_recurring" IS NULL));



CREATE INDEX "idx_transactions_recurring" ON "public"."transactions_table" USING "btree" ("user_id", "is_recurring", "date");



CREATE INDEX "idx_transactions_table_account_spend_date" ON "public"."transactions_table" USING "btree" ("account_id", "spend_date" DESC) WHERE ("spend_date" IS NOT NULL);



CREATE INDEX "idx_transactions_table_user_spend_date" ON "public"."transactions_table" USING "btree" ("user_id", "spend_date" DESC) WHERE ("spend_date" IS NOT NULL);



CREATE INDEX "idx_transactions_transaction_id" ON "public"."transactions_table" USING "btree" ("transaction_id");



CREATE INDEX "idx_transactions_user_date" ON "public"."transactions_table" USING "btree" ("user_id", "date");



CREATE INDEX "idx_transactions_user_id" ON "public"."transactions_table" USING "btree" ("user_id");



CREATE UNIQUE INDEX "idx_unique_manual_streams" ON "public"."recurring_streams_table" USING "btree" ("user_id", "match_pattern") WHERE ("is_manual" = true);



CREATE UNIQUE INDEX "idx_unique_plaid_streams" ON "public"."recurring_streams_table" USING "btree" ("user_id", "plaid_stream_id") WHERE (("plaid_stream_id" IS NOT NULL) AND ("is_manual" = false));



CREATE INDEX "refresh_jobs_status_idx" ON "public"."refresh_jobs" USING "btree" ("status");



CREATE INDEX "refresh_jobs_user_id_idx" ON "public"."refresh_jobs" USING "btree" ("user_id");



CREATE INDEX "transactions_table_amount_idx" ON "public"."transactions_table" USING "btree" ("amount");



CREATE OR REPLACE TRIGGER "accounts_updated_at_timestamp" BEFORE UPDATE ON "public"."accounts_table" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "assets_updated_at_timestamp" BEFORE UPDATE ON "public"."assets_table" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "institutions_updated_at_timestamp" BEFORE UPDATE ON "public"."institutions_table" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "items_updated_at_timestamp" BEFORE UPDATE ON "public"."items_table" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "profiles_updated_at_timestamp" BEFORE UPDATE ON "public"."profiles_table" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "set_transaction_spend_date_trigger" BEFORE INSERT OR UPDATE OF "date", "authorized_date", "authorized_datetime", "datetime", "pending", "created_at" ON "public"."transactions_table" FOR EACH ROW EXECUTE FUNCTION "public"."set_transaction_spend_date"();



CREATE OR REPLACE TRIGGER "transactions_updated_at_timestamp" BEFORE UPDATE ON "public"."transactions_table" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "trigger_update_goal_amount" AFTER INSERT OR DELETE ON "public"."savings_deposits_table" FOR EACH ROW EXECUTE FUNCTION "public"."update_goal_current_amount"();



ALTER TABLE ONLY "public"."accounts_table"
    ADD CONSTRAINT "accounts_table_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."items_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."assets_table"
    ADD CONSTRAINT "assets_table_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."items_table"
    ADD CONSTRAINT "items_table_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."link_events_table"
    ADD CONSTRAINT "link_events_table_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plaid_api_events_table"
    ADD CONSTRAINT "plaid_api_events_table_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles_table"
    ADD CONSTRAINT "profiles_table_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."recurring_stream_transactions_table"
    ADD CONSTRAINT "recurring_stream_transactions_table_stream_id_fkey" FOREIGN KEY ("stream_id") REFERENCES "public"."recurring_streams_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."recurring_stream_transactions_table"
    ADD CONSTRAINT "recurring_stream_transactions_table_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "public"."transactions_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."recurring_streams_table"
    ADD CONSTRAINT "recurring_streams_table_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."accounts_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."recurring_streams_table"
    ADD CONSTRAINT "recurring_streams_table_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."items_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."recurring_streams_table"
    ADD CONSTRAINT "recurring_streams_table_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."refresh_jobs"
    ADD CONSTRAINT "refresh_jobs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."savings_deposits_table"
    ADD CONSTRAINT "savings_deposits_table_goal_id_fkey" FOREIGN KEY ("goal_id") REFERENCES "public"."savings_goals_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."savings_deposits_table"
    ADD CONSTRAINT "savings_deposits_table_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."savings_goals_table"
    ADD CONSTRAINT "savings_goals_table_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transactions_table"
    ADD CONSTRAINT "transactions_table_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."accounts_table"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transactions_table"
    ADD CONSTRAINT "transactions_table_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles_table"("id") ON DELETE CASCADE;



CREATE POLICY "Authenticated users can view institutions" ON "public"."institutions_table" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Service role can delete institutions" ON "public"."institutions_table" FOR DELETE TO "service_role" USING (true);



CREATE POLICY "Service role can insert institutions" ON "public"."institutions_table" FOR INSERT TO "service_role" WITH CHECK (true);



CREATE POLICY "Service role can update institutions" ON "public"."institutions_table" FOR UPDATE TO "service_role" USING (true);



CREATE POLICY "Users can delete their own accounts" ON "public"."accounts_table" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."items_table"
  WHERE (("items_table"."id" = "accounts_table"."item_id") AND ("items_table"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Users can delete their own assets" ON "public"."assets_table" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can delete their own items" ON "public"."items_table" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can delete their own recurring streams" ON "public"."recurring_streams_table" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can delete their own refresh jobs" ON "public"."refresh_jobs" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can delete their own transactions" ON "public"."transactions_table" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own API events" ON "public"."plaid_api_events_table" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own accounts" ON "public"."accounts_table" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."items_table"
  WHERE (("items_table"."id" = "accounts_table"."item_id") AND ("items_table"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Users can insert their own assets" ON "public"."assets_table" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own items" ON "public"."items_table" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own link events" ON "public"."link_events_table" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own profile" ON "public"."profiles_table" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can insert their own recurring streams" ON "public"."recurring_streams_table" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own refresh jobs" ON "public"."refresh_jobs" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert their own transactions" ON "public"."transactions_table" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can manage their own savings deposits" ON "public"."savings_deposits_table" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can manage their own savings goals" ON "public"."savings_goals_table" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update their own accounts" ON "public"."accounts_table" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."items_table"
  WHERE (("items_table"."id" = "accounts_table"."item_id") AND ("items_table"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Users can update their own assets" ON "public"."assets_table" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update their own items" ON "public"."items_table" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update their own profile" ON "public"."profiles_table" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can update their own recurring streams" ON "public"."recurring_streams_table" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update their own refresh jobs" ON "public"."refresh_jobs" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update their own transactions" ON "public"."transactions_table" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own API events" ON "public"."plaid_api_events_table" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own accounts" ON "public"."accounts_table" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."items_table"
  WHERE (("items_table"."id" = "accounts_table"."item_id") AND ("items_table"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Users can view their own assets" ON "public"."assets_table" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own items" ON "public"."items_table" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own link events" ON "public"."link_events_table" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own profile" ON "public"."profiles_table" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can view their own recurring streams" ON "public"."recurring_streams_table" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own refresh jobs" ON "public"."refresh_jobs" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their own transactions" ON "public"."transactions_table" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view their stream transaction links" ON "public"."recurring_stream_transactions_table" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."recurring_streams_table" "rs"
  WHERE (("rs"."id" = "recurring_stream_transactions_table"."stream_id") AND ("rs"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



ALTER TABLE "public"."accounts_table" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."assets_table" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."institutions_table" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."items_table" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."link_events_table" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."plaid_api_events_table" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles_table" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."recurring_stream_transactions_table" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."recurring_streams_table" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."refresh_jobs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."savings_deposits_table" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."savings_goals_table" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."transactions_table" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."compute_transaction_spend_date"("tx_date" "date", "tx_authorized_date" "date", "tx_authorized_datetime" timestamp with time zone, "tx_pending" boolean, "tx_created_at" timestamp with time zone, "local_timezone" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."compute_transaction_spend_date"("tx_date" "date", "tx_authorized_date" "date", "tx_authorized_datetime" timestamp with time zone, "tx_pending" boolean, "tx_created_at" timestamp with time zone, "local_timezone" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_transaction_spend_date"("tx_date" "date", "tx_authorized_date" "date", "tx_authorized_datetime" timestamp with time zone, "tx_pending" boolean, "tx_created_at" timestamp with time zone, "local_timezone" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_daily_transaction_stats"("start_date" "date", "end_date" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_daily_transaction_stats"("start_date" "date", "end_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_daily_transaction_stats"("start_date" "date", "end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_daily_transaction_stats"("start_date" "date", "end_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_goals_summary"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_goals_summary"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_goals_summary"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_monthly_income_summary"("p_start" "date", "p_end" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_monthly_income_summary"("p_start" "date", "p_end" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_monthly_income_summary"("p_start" "date", "p_end" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_monthly_income_summary"("p_start" "date", "p_end" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_monthly_transaction_stats"("start_date" "date", "end_date" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_monthly_transaction_stats"("start_date" "date", "end_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_monthly_transaction_stats"("start_date" "date", "end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_monthly_transaction_stats"("start_date" "date", "end_date" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_net_cash_balance"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_net_cash_balance"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_net_cash_balance"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_net_cash_balance"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_period_spend_comparison"("p_prev_week_start" "date", "p_prev_week_same_day_end" "date", "p_prev_month_start" "date", "p_prev_month_same_day_end" "date", "p_current_week_start" "date", "p_today" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_period_spend_comparison"("p_prev_week_start" "date", "p_prev_week_same_day_end" "date", "p_prev_month_start" "date", "p_prev_month_same_day_end" "date", "p_current_week_start" "date", "p_today" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_period_spend_comparison"("p_prev_week_start" "date", "p_prev_week_same_day_end" "date", "p_prev_month_start" "date", "p_prev_month_same_day_end" "date", "p_current_week_start" "date", "p_today" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_period_spend_comparison"("p_prev_week_start" "date", "p_prev_week_same_day_end" "date", "p_prev_month_start" "date", "p_prev_month_same_day_end" "date", "p_current_week_start" "date", "p_today" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_pulse_top_merchants"("start_date" "date", "end_date" "date", "lim" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_pulse_top_merchants"("start_date" "date", "end_date" "date", "lim" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_pulse_top_merchants"("start_date" "date", "end_date" "date", "lim" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_pulse_top_merchants"("start_date" "date", "end_date" "date", "lim" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_pulse_weekly_energy"("week_start" "date", "week_end" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_pulse_weekly_energy"("week_start" "date", "week_end" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_pulse_weekly_energy"("week_start" "date", "week_end" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_pulse_weekly_energy"("week_start" "date", "week_end" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_spending_breakdown"("p_start" "date", "p_end" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_spending_breakdown"("p_start" "date", "p_end" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_spending_breakdown"("p_start" "date", "p_end" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_spending_breakdown"("p_start" "date", "p_end" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_spending_streak"("p_today" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_spending_streak"("p_today" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_variable_spend"("p_start" "date", "p_end" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_variable_spend"("p_start" "date", "p_end" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_variable_spend"("p_start" "date", "p_end" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_variable_spend"("p_start" "date", "p_end" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_new_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."profile_time_zone_for_user"("profile_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."profile_time_zone_for_user"("profile_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."profile_time_zone_for_user"("profile_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_transaction_spend_date"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_transaction_spend_date"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_transaction_spend_date"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."update_goal_current_amount"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_goal_current_amount"() TO "service_role";



GRANT ALL ON TABLE "public"."accounts_table" TO "anon";
GRANT ALL ON TABLE "public"."accounts_table" TO "authenticated";
GRANT ALL ON TABLE "public"."accounts_table" TO "service_role";



GRANT ALL ON TABLE "public"."items_table" TO "anon";
GRANT ALL ON TABLE "public"."items_table" TO "authenticated";
GRANT ALL ON TABLE "public"."items_table" TO "service_role";



GRANT ALL ON TABLE "public"."accounts" TO "anon";
GRANT ALL ON TABLE "public"."accounts" TO "authenticated";
GRANT ALL ON TABLE "public"."accounts" TO "service_role";



GRANT ALL ON SEQUENCE "public"."accounts_table_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."accounts_table_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."accounts_table_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."institutions_table" TO "anon";
GRANT ALL ON TABLE "public"."institutions_table" TO "authenticated";
GRANT ALL ON TABLE "public"."institutions_table" TO "service_role";



GRANT ALL ON TABLE "public"."accounts_with_banks" TO "anon";
GRANT ALL ON TABLE "public"."accounts_with_banks" TO "authenticated";
GRANT ALL ON TABLE "public"."accounts_with_banks" TO "service_role";



GRANT ALL ON TABLE "public"."recurring_streams_table" TO "anon";
GRANT ALL ON TABLE "public"."recurring_streams_table" TO "authenticated";
GRANT ALL ON TABLE "public"."recurring_streams_table" TO "service_role";



GRANT ALL ON TABLE "public"."active_mandatory_expense_streams" TO "anon";
GRANT ALL ON TABLE "public"."active_mandatory_expense_streams" TO "authenticated";
GRANT ALL ON TABLE "public"."active_mandatory_expense_streams" TO "service_role";



GRANT ALL ON TABLE "public"."active_subscription_streams" TO "anon";
GRANT ALL ON TABLE "public"."active_subscription_streams" TO "authenticated";
GRANT ALL ON TABLE "public"."active_subscription_streams" TO "service_role";



GRANT ALL ON TABLE "public"."assets_table" TO "anon";
GRANT ALL ON TABLE "public"."assets_table" TO "authenticated";
GRANT ALL ON TABLE "public"."assets_table" TO "service_role";



GRANT ALL ON TABLE "public"."assets" TO "anon";
GRANT ALL ON TABLE "public"."assets" TO "authenticated";
GRANT ALL ON TABLE "public"."assets" TO "service_role";



GRANT ALL ON SEQUENCE "public"."assets_table_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."assets_table_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."assets_table_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."institutions" TO "anon";
GRANT ALL ON TABLE "public"."institutions" TO "authenticated";
GRANT ALL ON TABLE "public"."institutions" TO "service_role";



GRANT ALL ON SEQUENCE "public"."institutions_table_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."institutions_table_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."institutions_table_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."items" TO "anon";
GRANT ALL ON TABLE "public"."items" TO "authenticated";
GRANT ALL ON TABLE "public"."items" TO "service_role";



GRANT ALL ON SEQUENCE "public"."items_table_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."items_table_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."items_table_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."link_events_table" TO "anon";
GRANT ALL ON TABLE "public"."link_events_table" TO "authenticated";
GRANT ALL ON TABLE "public"."link_events_table" TO "service_role";



GRANT ALL ON SEQUENCE "public"."link_events_table_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."link_events_table_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."link_events_table_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."plaid_api_events_table" TO "anon";
GRANT ALL ON TABLE "public"."plaid_api_events_table" TO "authenticated";
GRANT ALL ON TABLE "public"."plaid_api_events_table" TO "service_role";



GRANT ALL ON SEQUENCE "public"."plaid_api_events_table_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."plaid_api_events_table_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."plaid_api_events_table_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."profiles_table" TO "anon";
GRANT ALL ON TABLE "public"."profiles_table" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles_table" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."recurring_stream_transactions_table" TO "anon";
GRANT ALL ON TABLE "public"."recurring_stream_transactions_table" TO "authenticated";
GRANT ALL ON TABLE "public"."recurring_stream_transactions_table" TO "service_role";



GRANT ALL ON SEQUENCE "public"."recurring_stream_transactions_table_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."recurring_stream_transactions_table_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."recurring_stream_transactions_table_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."recurring_streams_table_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."recurring_streams_table_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."recurring_streams_table_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."refresh_jobs" TO "anon";
GRANT ALL ON TABLE "public"."refresh_jobs" TO "authenticated";
GRANT ALL ON TABLE "public"."refresh_jobs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."refresh_jobs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."refresh_jobs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."refresh_jobs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."savings_deposits_table" TO "anon";
GRANT ALL ON TABLE "public"."savings_deposits_table" TO "authenticated";
GRANT ALL ON TABLE "public"."savings_deposits_table" TO "service_role";



GRANT ALL ON SEQUENCE "public"."savings_deposits_table_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."savings_deposits_table_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."savings_deposits_table_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."savings_goals_table" TO "anon";
GRANT ALL ON TABLE "public"."savings_goals_table" TO "authenticated";
GRANT ALL ON TABLE "public"."savings_goals_table" TO "service_role";



GRANT ALL ON SEQUENCE "public"."savings_goals_table_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."savings_goals_table_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."savings_goals_table_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."transactions_table" TO "anon";
GRANT ALL ON TABLE "public"."transactions_table" TO "authenticated";
GRANT ALL ON TABLE "public"."transactions_table" TO "service_role";



GRANT ALL ON TABLE "public"."transactions" TO "anon";
GRANT ALL ON TABLE "public"."transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."transactions" TO "service_role";



GRANT ALL ON TABLE "public"."spendable_income_transactions" TO "anon";
GRANT ALL ON TABLE "public"."spendable_income_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."spendable_income_transactions" TO "service_role";



GRANT ALL ON SEQUENCE "public"."transactions_table_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."transactions_table_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."transactions_table_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."variable_transactions" TO "anon";
GRANT ALL ON TABLE "public"."variable_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."variable_transactions" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







-- ===== END GENERATED SCHEMA ==================================================

-- =============================================================================
-- auth.users signup trigger (maintained by hand)
-- A `--schema public` dump cannot see objects in the `auth` schema. The
-- handle_new_user() function above lives in public and IS included by the dump,
-- but the trigger that fires it on new signups lives on auth.users and must be
-- recreated here so a from-scratch setup auto-provisions a profiles_table row.
-- =============================================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
