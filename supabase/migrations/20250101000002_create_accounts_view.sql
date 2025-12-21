-- Migration: Create accounts_with_banks view
-- Phase 4: iOS Services Migration
-- Date: 2025-12-14
--
-- Purpose: Efficiently join accounts with their bank (institution) information
-- for the iOS AccountsService to fetch in a single query.

CREATE OR REPLACE VIEW accounts_with_banks AS
SELECT
    a.id,
    a.item_id,
    a.name,
    a.mask,
    a.official_name,
    a.current_balance,
    a.available_balance,
    a.type,
    a.subtype,
    a.hidden,
    a.plaid_account_id as account_id,
    a.iso_currency_code,
    a.created_at,
    a.updated_at,
    -- Institution fields (joined via items)
    i.id as institution_id,
    i.name as institution_name,
    i.logo as institution_logo,
    i.primary_color as institution_color,
    i.url as institution_url,
    -- User ID from items
    it.user_id
FROM accounts_table a
JOIN items_table it ON a.item_id = it.id
JOIN institutions_table i ON it.plaid_institution_id = i.institution_id;

-- Add RLS policy for the view
-- The view will automatically filter by user_id through the accounts table RLS
ALTER VIEW accounts_with_banks SET (security_invoker = true);

-- Grant access to authenticated users
GRANT SELECT ON accounts_with_banks TO authenticated;

COMMENT ON VIEW accounts_with_banks IS 'View that joins accounts with their bank institution information for efficient querying by iOS app';
