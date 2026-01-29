-- Update variable_transactions view to filter out TRANSFER_OUT and LOAN_PAYMENTS categories
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
    )
    -- Filter out transfer and loan payment categories
    AND (t.personal_finance_category NOT ILIKE 'TRANSFER_OUT%')
    AND (t.personal_finance_category NOT ILIKE 'LOAN_PAYMENTS%');
