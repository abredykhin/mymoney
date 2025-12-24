-- Migration to add missing foreign key indexes for performance
-- These indexes are critical for RLS performance and join efficiency

-- Items Table
CREATE INDEX IF NOT EXISTS idx_items_user_id ON items_table(user_id);

-- Accounts Table
-- accounts(item_id) is used often to link account -> item -> user
CREATE INDEX IF NOT EXISTS idx_accounts_item_id ON accounts_table(item_id);
-- accounts(plaid_account_id) is used for lookups during sync
CREATE INDEX IF NOT EXISTS idx_accounts_plaid_account_id ON accounts_table(plaid_account_id);

-- Assets Table
CREATE INDEX IF NOT EXISTS idx_assets_user_id ON assets_table(user_id);

-- Link Events Table
CREATE INDEX IF NOT EXISTS idx_link_events_user_id ON link_events_table(user_id);

-- Plaid API Events Table
CREATE INDEX IF NOT EXISTS idx_plaid_api_events_user_id ON plaid_api_events_table(user_id);
CREATE INDEX IF NOT EXISTS idx_plaid_api_events_item_id ON plaid_api_events_table(item_id);
