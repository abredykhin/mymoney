-- Migration to add missing indexes for performance optimization
-- These indexes support the transaction stats RPC functions and general filtering

-- Index for filtering transactions by user (essential for RLS and all queries)
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions_table(user_id);

-- Index for filtering by date range (used in stats and history view)
-- specific composite index might be better: (user_id, date)
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON transactions_table(user_id, date);

-- Index for filtering by account (used when viewing specific account)
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions_table(account_id);
