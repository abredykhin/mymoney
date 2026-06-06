-- The Lineup (Pulse "top merchants") must reconcile to the Damage Report headline.
--
-- Bug: get_pulse_top_merchants was never migrated off its original ad-hoc filter
-- (from 20260523000000). It queried transactions_table directly with
--   amount > 0 AND personal_finance_category NOT ILIKE '%TRANSFER%'
-- which filters on a layer that exists nowhere else in the app:
--   * it DROPS every transfer — so external/spousal wires
--     (TRANSFER_OUT_OTHER_TRANSFER_OUT) that DO count as spend in the Swing layer
--     were excluded, hiding the user's single biggest outflow from "top merchants";
--   * it KEEPS credit-card payments (LOAN_PAYMENTS_CREDIT_CARD_PAYMENT), which
--     is_spend deliberately excludes to avoid double-counting the payoff against
--     the purchases — so card payments showed up as phantom "Other" merchants.
-- The rings ("% of the damage") are computed against the Damage total, but the
-- merchant set didn't match that denominator, so they never reconciled.
--
-- Fix: source the lineup from the `transactions` view filtered by is_spend = true,
-- exactly like the Damage headline (get_daily_transaction_stats) and "Where it went"
-- (fetchCategoryBreakdown). This is the total-spend Swing layer per CLAUDE.md:
-- bills/mandatory rows stay visible (they are is_spend), external wires are included,
-- credit-card payments and income are excluded. SECURITY INVOKER over the
-- security_invoker view applies the caller's RLS, matching the other Swing RPCs.
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
SECURITY INVOKER SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(t.merchant_name, t.name) AS merchant_name,
        SUM(ABS(t.amount))::double precision AS total_spent,
        COUNT(*)::bigint AS transaction_count,
        MIN(t.personal_finance_category) AS personal_finance_category
    FROM
        public.transactions t
    WHERE
        t.user_id = auth.uid()
        AND t.spend_date BETWEEN start_date AND end_date
        AND t.is_spend
    GROUP BY
        COALESCE(t.merchant_name, t.name)
    ORDER BY
        total_spent DESC
    LIMIT
        lim;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_pulse_top_merchants(date, date, integer) TO authenticated;
