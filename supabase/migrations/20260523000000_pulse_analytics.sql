-- Create Pulse Analytics Functions
-- Driving the Week Day Spending Energy and The Lineup (Top Merchants)

-- Drop existing functions to ensure clean replacement
DROP FUNCTION IF EXISTS public.get_pulse_weekly_energy(date, date);
DROP FUNCTION IF EXISTS public.get_pulse_top_merchants(date, date, integer);

-- 1. Daily energy weekday spending aggregation
CREATE OR REPLACE FUNCTION public.get_pulse_weekly_energy(
    week_start DATE,
    week_end DATE
)
RETURNS TABLE (
    weekday TEXT,
    date_label DATE,
    total_spent DOUBLE PRECISION,
    is_peak BOOLEAN,
    peak_merchant TEXT,
    peak_category TEXT,
    peak_amount DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    peak_date DATE;
BEGIN
    -- Find the day in the range with the absolute highest spending
    SELECT COALESCE(t.authorized_date, t.date) INTO peak_date
    FROM public.transactions_table t
    WHERE t.user_id = auth.uid()
      AND COALESCE(t.authorized_date, t.date) BETWEEN week_start AND week_end
      AND t.amount > 0
      AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    GROUP BY COALESCE(t.authorized_date, t.date)
    ORDER BY SUM(t.amount) DESC
    LIMIT 1;

    -- Return daily stats along with peak transaction details
    RETURN QUERY
    WITH daily_totals AS (
        SELECT 
            COALESCE(t.authorized_date, t.date) as t_date,
            SUM(t.amount)::double precision as t_sum
        FROM public.transactions_table t
        WHERE t.user_id = auth.uid()
          AND COALESCE(t.authorized_date, t.date) BETWEEN week_start AND week_end
          AND t.amount > 0
          AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
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
    SELECT 
        TO_CHAR(d.date_series, 'Dy') as weekday,
        d.date_series::date as date_label,
        COALESCE(dt.t_sum, 0.0)::double precision as total_spent,
        (d.date_series::date = peak_date) as is_peak,
        COALESCE(pt.merchant, 'No Spend') as peak_merchant,
        pt.category as peak_category,
        COALESCE(pt.amount, 0.0)::double precision as peak_amount
    FROM 
        GENERATE_SERIES(week_start::timestamp, week_end::timestamp, '1 day'::interval) d(date_series)
    LEFT JOIN daily_totals dt ON dt.t_date = d.date_series::date
    LEFT JOIN peak_transactions pt ON pt.t_date = d.date_series::date
    ORDER BY d.date_series ASC;
END;
$$;

-- 2. Ranked Top Merchants (The Lineup)
CREATE OR REPLACE FUNCTION public.get_pulse_top_merchants(
    start_date DATE,
    end_date DATE,
    lim INTEGER DEFAULT 5
)
RETURNS TABLE (
    merchant_name TEXT,
    total_spent DOUBLE PRECISION,
    transaction_count BIGINT,
    personal_finance_category TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(t.merchant_name, t.name) as merchant_name,
        SUM(t.amount)::double precision as total_spent,
        COUNT(*)::bigint as transaction_count,
        MIN(t.personal_finance_category) as personal_finance_category
    FROM 
        public.transactions_table t
    WHERE 
        t.user_id = auth.uid()
        AND COALESCE(t.authorized_date, t.date) BETWEEN start_date AND end_date
        AND t.amount > 0
        AND (t.personal_finance_category IS NULL OR t.personal_finance_category NOT ILIKE '%TRANSFER%')
    GROUP BY 
        COALESCE(t.merchant_name, t.name)
    ORDER BY 
        total_spent DESC
    LIMIT 
        lim;
END;
$$;
