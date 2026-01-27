-- Create a view that filters out fixed expenses from the transactions view
-- This allows the client to query "variable" spending directly without complex client-side filtering

CREATE OR REPLACE VIEW variable_transactions AS
SELECT
    t.*
FROM
    transactions t
WHERE
    -- Filter out transactions that match any "fixed_expense" budget item pattern
    NOT EXISTS (
        SELECT 1
        FROM budget_items_table bi
        WHERE
            bi.user_id = t.user_id
            AND bi.type = 'fixed_expense'
            AND bi.is_active = true
            AND t.name ILIKE bi.pattern
    );

-- Grant access to the view (inherits RLS from underlying tables usually, but good to be explicit if needed)
-- Since it's a view on a view, and standard view `transactions` has RLS via underlying tables, this should work standardly.
