-- Expand spend filter:
--   TRANSFER_OUT_OTHER_TRANSFER_OUT → count as spending (Oaks Corner, wire transfers)
--   TRANSFER_IN_ACCOUNT_TRANSFER   → count as income (wire reversals cancel reversed wires)
--
-- Wire pair example:
--   May 3  +$47,413 TRANSFER_OUT_OTHER_TRANSFER_OUT → total_out += $47k
--   May 4  -$47,413 TRANSFER_IN_ACCOUNT_TRANSFER    → total_in  += $47k
--   Net: $0 for the reversed wire, $47k net spend for the unreversed May 18 wire.
--
-- TRANSFER_IN subcategories still excluded:
--   TRANSFER_IN_INVESTMENT_AND_RETIREMENT_FUNDS  (Schwab MoneyLink — moving funds, not income)
--   TRANSFER_IN_CASH_ADVANCES_AND_LOANS          (credit card payment confirmations)

-- Shared filter macro (copy-pasted into each function/view below):
--
--   EXCLUDE if:
--     - TRANSFER_IN and subcategory is NOT ACCOUNT_TRANSFER
--     - TRANSFER_OUT and subcategory is NOT one of the three allowed types
--     - LOAN_PAYMENTS_CREDIT_CARD_PAYMENT (double-counting)
--     - NULL category with payment/transfer-like name
--     - INCOME with brokerage-like name

DROP FUNCTION IF EXISTS public.get_daily_transaction_stats(date, date);
DROP FUNCTION IF EXISTS public.get_monthly_transaction_stats(date, date);

CREATE OR REPLACE FUNCTION public.get_daily_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (date date, total_in double precision, total_out double precision)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(t.authorized_date, t.date) as date,
    COALESCE(SUM(CASE
      WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
      WHEN (a.type ILIKE 'depository' OR a.type ILIKE 'investment') AND t.amount < 0 THEN ABS(t.amount)
      ELSE 0
    END), 0)::double precision as total_in,
    COALESCE(SUM(CASE
      WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
      WHEN a.type ILIKE 'investment' THEN 0
      WHEN t.amount > 0 THEN t.amount
      ELSE 0
    END), 0)::double precision as total_out
  FROM public.transactions_table t
  JOIN public.accounts_table a ON t.account_id = a.id
  WHERE t.user_id = auth.uid()
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    AND (
      (
        t.personal_finance_category IS NOT NULL
        AND NOT (
          t.personal_finance_category = 'TRANSFER_IN'
          AND COALESCE(t.personal_finance_subcategory, '') != 'TRANSFER_IN_ACCOUNT_TRANSFER'
        )
        AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
        AND NOT (
          t.personal_finance_category = 'TRANSFER_OUT'
          AND COALESCE(t.personal_finance_subcategory, '') NOT IN (
            'TRANSFER_OUT_ACCOUNT_TRANSFER',
            'TRANSFER_OUT_WITHDRAWAL',
            'TRANSFER_OUT_OTHER_TRANSFER_OUT'
          )
        )
      )
      OR (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
    AND NOT (
      t.personal_finance_category = 'INCOME'
      AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
        '%transfer%', '%wire%', '%reversal%', '%brokerage%',
        '%bkrg%', '%schwab%', '%moneylink%', '%invest%', '%healthequity%'
      ])
    )
  GROUP BY 1 ORDER BY 1 DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_monthly_transaction_stats(
  start_date date,
  end_date date
)
RETURNS TABLE (year double precision, month double precision, total_in double precision, total_out double precision)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    EXTRACT(YEAR FROM COALESCE(t.authorized_date, t.date))::double precision,
    EXTRACT(MONTH FROM COALESCE(t.authorized_date, t.date))::double precision,
    COALESCE(SUM(CASE
      WHEN a.type ILIKE 'loan' AND t.amount > 0 THEN t.amount
      WHEN (a.type ILIKE 'depository' OR a.type ILIKE 'investment') AND t.amount < 0 THEN ABS(t.amount)
      ELSE 0
    END), 0)::double precision,
    COALESCE(SUM(CASE
      WHEN a.type ILIKE 'loan' AND t.amount < 0 THEN ABS(t.amount)
      WHEN a.type ILIKE 'investment' THEN 0
      WHEN t.amount > 0 THEN t.amount
      ELSE 0
    END), 0)::double precision
  FROM public.transactions_table t
  JOIN public.accounts_table a ON t.account_id = a.id
  WHERE t.user_id = auth.uid()
    AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
    AND (
      (
        t.personal_finance_category IS NOT NULL
        AND NOT (
          t.personal_finance_category = 'TRANSFER_IN'
          AND COALESCE(t.personal_finance_subcategory, '') != 'TRANSFER_IN_ACCOUNT_TRANSFER'
        )
        AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
        AND NOT (
          t.personal_finance_category = 'TRANSFER_OUT'
          AND COALESCE(t.personal_finance_subcategory, '') NOT IN (
            'TRANSFER_OUT_ACCOUNT_TRANSFER',
            'TRANSFER_OUT_WITHDRAWAL',
            'TRANSFER_OUT_OTHER_TRANSFER_OUT'
          )
        )
      )
      OR (
        t.personal_finance_category IS NULL
        AND t.name NOT ILIKE '%Payment%'
        AND t.name NOT ILIKE '%Transfer%'
      )
    )
    AND NOT (
      t.personal_finance_category = 'INCOME'
      AND COALESCE(t.name, '') ILIKE ANY (ARRAY[
        '%transfer%', '%wire%', '%reversal%', '%brokerage%',
        '%bkrg%', '%schwab%', '%moneylink%', '%invest%', '%healthequity%'
      ])
    )
  GROUP BY 1, 2 ORDER BY 1 DESC, 2 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_daily_transaction_stats(date, date) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_monthly_transaction_stats(date, date) TO authenticated;

-- variable_transactions (drives liquid hero budget widget)
CREATE OR REPLACE VIEW variable_transactions AS
SELECT t.*
FROM transactions t
WHERE
  (t.is_recurring = FALSE OR t.is_recurring IS NULL)
  AND NOT (
    t.personal_finance_category = 'TRANSFER_IN'
    AND COALESCE(t.personal_finance_subcategory, '') != 'TRANSFER_IN_ACCOUNT_TRANSFER'
  )
  AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
  AND NOT (
    t.personal_finance_category = 'TRANSFER_OUT'
    AND COALESCE(t.personal_finance_subcategory, '') NOT IN (
      'TRANSFER_OUT_ACCOUNT_TRANSFER',
      'TRANSFER_OUT_WITHDRAWAL',
      'TRANSFER_OUT_OTHER_TRANSFER_OUT'
    )
  );

ALTER VIEW variable_transactions SET (security_invoker = true);

-- get_user_spending_streak (streak only looks at amount > 0, TRANSFER_IN change is a no-op here)
CREATE OR REPLACE FUNCTION public.get_user_spending_streak()
RETURNS TABLE (current_streak INT, max_streak INT, last_10_days_status BOOLEAN[])
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
DECLARE
    income_val NUMERIC(28,2); actual_income NUMERIC(28,2); fixed_exp NUMERIC(28,2);
    daily_limit NUMERIC(28,2); streak_count INT := 0; max_streak_count INT := 0;
    temp_streak INT := 0; day_idx INT; spend_on_day NUMERIC(28,2);
    status_arr BOOLEAN[] := '{}'; day_date DATE; current_streak_set BOOLEAN := FALSE;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.items_table WHERE user_id = (SELECT auth.uid()) AND is_active = TRUE
    ) THEN RETURN; END IF;

    SELECT COALESCE(monthly_income, 0), COALESCE(monthly_mandatory_expenses, 0)
    INTO income_val, fixed_exp
    FROM public.profiles_table WHERE id = (SELECT auth.uid());

    SELECT COALESCE(SUM(ABS(amount)), 0) INTO actual_income
    FROM public.spendable_income_transactions
    WHERE user_id = (SELECT auth.uid())
      AND date >= DATE_TRUNC('month', CURRENT_DATE)::DATE
      AND date <= (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    income_val := GREATEST(income_val, actual_income);
    daily_limit := (income_val - fixed_exp) / 30.0;
    IF daily_limit <= 0 THEN daily_limit := 50.00; END IF;

    FOR day_idx IN 0..89 LOOP
        day_date := CURRENT_DATE - day_idx;
        SELECT COALESCE(SUM(amount), 0) INTO spend_on_day
        FROM public.transactions_table
        WHERE user_id = (SELECT auth.uid())
          AND COALESCE(authorized_date, date) = day_date
          AND amount > 0
          AND COALESCE(personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
          AND NOT (
            personal_finance_category = 'TRANSFER_OUT'
            AND COALESCE(personal_finance_subcategory, '') NOT IN (
              'TRANSFER_OUT_ACCOUNT_TRANSFER',
              'TRANSFER_OUT_WITHDRAWAL',
              'TRANSFER_OUT_OTHER_TRANSFER_OUT'
            )
          );

        IF spend_on_day <= daily_limit THEN
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

REVOKE EXECUTE ON FUNCTION public.get_user_spending_streak() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_user_spending_streak() TO authenticated;

-- get_pulse_weekly_energy
DROP FUNCTION IF EXISTS public.get_pulse_weekly_energy(date, date);
CREATE OR REPLACE FUNCTION public.get_pulse_weekly_energy(week_start DATE, week_end DATE)
RETURNS TABLE (weekday TEXT, date_label DATE, total_spent DOUBLE PRECISION,
               is_peak BOOLEAN, peak_merchant TEXT, peak_category TEXT, peak_amount DOUBLE PRECISION)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
DECLARE peak_date DATE;
BEGIN
    SELECT COALESCE(t.authorized_date, t.date) INTO peak_date
    FROM public.transactions_table t
    WHERE t.user_id = auth.uid()
      AND COALESCE(t.authorized_date, t.date) BETWEEN week_start AND week_end
      AND t.amount > 0
      AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
      AND NOT (
        t.personal_finance_category = 'TRANSFER_OUT'
        AND COALESCE(t.personal_finance_subcategory, '') NOT IN (
          'TRANSFER_OUT_ACCOUNT_TRANSFER', 'TRANSFER_OUT_WITHDRAWAL', 'TRANSFER_OUT_OTHER_TRANSFER_OUT'
        )
      )
    GROUP BY COALESCE(t.authorized_date, t.date)
    ORDER BY SUM(t.amount) DESC LIMIT 1;

    RETURN QUERY
    WITH daily_totals AS (
        SELECT COALESCE(t.authorized_date, t.date) as t_date, SUM(t.amount)::double precision as t_sum
        FROM public.transactions_table t
        WHERE t.user_id = auth.uid()
          AND COALESCE(t.authorized_date, t.date) BETWEEN week_start AND week_end
          AND t.amount > 0
          AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
          AND NOT (
            t.personal_finance_category = 'TRANSFER_OUT'
            AND COALESCE(t.personal_finance_subcategory, '') NOT IN (
              'TRANSFER_OUT_ACCOUNT_TRANSFER', 'TRANSFER_OUT_WITHDRAWAL', 'TRANSFER_OUT_OTHER_TRANSFER_OUT'
            )
          )
        GROUP BY COALESCE(t.authorized_date, t.date)
    ),
    peak_transactions AS (
        SELECT DISTINCT ON (COALESCE(t.authorized_date, t.date))
            COALESCE(t.authorized_date, t.date) as t_date,
            COALESCE(t.merchant_name, t.name) as merchant,
            t.personal_finance_category as category,
            t.amount::double precision as amount
        FROM public.transactions_table t
        WHERE t.user_id = auth.uid()
          AND COALESCE(t.authorized_date, t.date) BETWEEN week_start AND week_end
          AND t.amount > 0
        ORDER BY COALESCE(t.authorized_date, t.date), t.amount DESC
    )
    SELECT TO_CHAR(d.date_series, 'Dy'), d.date_series::date,
           COALESCE(dt.t_sum, 0.0)::double precision, (d.date_series::date = peak_date),
           COALESCE(pt.merchant, 'No Spend'), pt.category, COALESCE(pt.amount, 0.0)::double precision
    FROM GENERATE_SERIES(week_start::timestamp, week_end::timestamp, '1 day'::interval) d(date_series)
    LEFT JOIN daily_totals dt ON dt.t_date = d.date_series::date
    LEFT JOIN peak_transactions pt ON pt.t_date = d.date_series::date
    ORDER BY d.date_series ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_pulse_weekly_energy(date, date) TO authenticated;

-- get_pulse_top_merchants
DROP FUNCTION IF EXISTS public.get_pulse_top_merchants(date, date, integer);
CREATE OR REPLACE FUNCTION public.get_pulse_top_merchants(start_date DATE, end_date DATE, lim INTEGER DEFAULT 5)
RETURNS TABLE (merchant_name TEXT, total_spent DOUBLE PRECISION, transaction_count BIGINT, personal_finance_category TEXT)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT COALESCE(t.merchant_name, t.name), SUM(t.amount)::double precision,
           COUNT(*)::bigint, MIN(t.personal_finance_category)
    FROM public.transactions_table t
    WHERE t.user_id = auth.uid()
      AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
      AND t.amount > 0
      AND COALESCE(t.personal_finance_subcategory, '') != 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
      AND NOT (
        t.personal_finance_category = 'TRANSFER_OUT'
        AND COALESCE(t.personal_finance_subcategory, '') NOT IN (
          'TRANSFER_OUT_ACCOUNT_TRANSFER', 'TRANSFER_OUT_WITHDRAWAL', 'TRANSFER_OUT_OTHER_TRANSFER_OUT'
        )
      )
    GROUP BY COALESCE(t.merchant_name, t.name)
    ORDER BY total_spent DESC LIMIT lim;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) TO authenticated;
