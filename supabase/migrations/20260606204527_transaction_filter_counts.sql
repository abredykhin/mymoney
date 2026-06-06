-- Lightweight chip-count source for the All-activity sheet (AllTransactionsView).
--
-- The filter chips (All / Out / In / category / Other / Bills) need COMPLETE, stable
-- counts for a date range. Previously the client derived them from the loaded rows, so
-- they were wrong for a merchant drill-down (counted the whole period) and grew as the
-- list paginated. Loading every row just to count them is wasteful, so this returns the
-- numbers instead.
--
-- Category bucketing (FlexibleSpendingCategory.map) is client-side Swift and must stay
-- the single source of truth, so this groups by the RAW Plaid classification columns
-- only and lets the client map each group to a chip. The result is a few dozen rows at
-- most (distinct flag/category combinations), independent of transaction volume.
--
-- Restricted to spend-or-income rows — the exact universe the activity list renders —
-- and optionally narrowed by a merchant/category text search, matching the client's
-- search predicate (displayName = merchant_name ?? name, plus the category text).

CREATE OR REPLACE FUNCTION public.get_transaction_filter_counts(
    start_date DATE,
    end_date DATE,
    search TEXT DEFAULT NULL
)
RETURNS TABLE (
    is_spend BOOLEAN,
    is_income BOOLEAN,
    is_mandatory BOOLEAN,
    personal_finance_category TEXT,
    personal_finance_subcategory TEXT,
    cnt BIGINT
)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT t.is_spend, t.is_income, t.is_mandatory,
           t.personal_finance_category, t.personal_finance_subcategory,
           COUNT(*)::bigint
    FROM public.transactions t
    WHERE t.user_id = auth.uid()
      AND t.spend_date BETWEEN start_date AND end_date
      AND (t.is_spend OR t.is_income)
      AND (
        search IS NULL OR search = ''
        OR COALESCE(t.merchant_name, t.name) ILIKE '%' || search || '%'
        OR t.personal_finance_category ILIKE '%' || search || '%'
      )
    GROUP BY t.is_spend, t.is_income, t.is_mandatory,
             t.personal_finance_category, t.personal_finance_subcategory;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_transaction_filter_counts(date, date, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_transaction_filter_counts(date, date, text) TO authenticated;
