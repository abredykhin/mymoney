-- Push the spending category GROUP BY into the DB so any client gets pre-aggregated
-- data instead of fetching every transaction row and grouping in memory.
--
-- Mirrors BudgetService.fetchTotalSpend(): groups is_spend transactions by
-- personal_finance_category, returns total_spent + transaction_count + percent_of_total.
-- percent_of_total is 0–100 (matches existing BudgetCategoryItem expectations).

CREATE OR REPLACE FUNCTION public.get_spending_breakdown(p_start date, p_end date)
RETURNS TABLE (
    category          text,
    total_spent       double precision,
    transaction_count bigint,
    percent_of_total  double precision
)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public
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

REVOKE EXECUTE ON FUNCTION public.get_spending_breakdown(date, date) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_spending_breakdown(date, date) TO authenticated;
