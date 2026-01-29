-- Fix security issue: Create view with SECURITY INVOKER to respect RLS policies
-- This ensures the view runs with the querying user's permissions, not the creator's
CREATE OR REPLACE VIEW variable_transactions
WITH (security_invoker = true)
AS
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
    )
    -- Filter out income, transfers, and loan-related categories (not actual spending)
    AND t.personal_finance_category NOT IN (
        'INCOME',
        'LOAN_DISBURSEMENTS',
        'LOAN_PAYMENTS',
        'TRANSFER_IN',
        'TRANSFER_OUT'
    );
