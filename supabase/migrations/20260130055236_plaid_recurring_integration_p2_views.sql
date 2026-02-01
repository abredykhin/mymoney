
CREATE OR REPLACE VIEW variable_transactions AS
SELECT t.*
FROM transactions t
WHERE t.is_recurring = FALSE
   OR t.is_recurring IS NULL;

ALTER VIEW variable_transactions SET (security_invoker = true);
