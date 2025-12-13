-- Enable Row Level Security on all tables
-- This ensures users can only access their own data

-- Enable RLS on all user-related tables
ALTER TABLE profiles_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE items_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE refresh_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE link_events_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE plaid_api_events_table ENABLE ROW LEVEL SECURITY;

-- Profiles policies
-- Users can read and update their own profile
CREATE POLICY "Users can view their own profile"
  ON profiles_table
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles_table
  FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
  ON profiles_table
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Items policies
-- Users can only access items that belong to them
CREATE POLICY "Users can view their own items"
  ON items_table
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own items"
  ON items_table
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own items"
  ON items_table
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own items"
  ON items_table
  FOR DELETE
  USING (auth.uid() = user_id);

-- Assets policies
-- Users can only access assets that belong to them
CREATE POLICY "Users can view their own assets"
  ON assets_table
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own assets"
  ON assets_table
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own assets"
  ON assets_table
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own assets"
  ON assets_table
  FOR DELETE
  USING (auth.uid() = user_id);

-- Accounts policies
-- Users can only access accounts through their items
CREATE POLICY "Users can view their own accounts"
  ON accounts_table
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM items_table
      WHERE items_table.id = accounts_table.item_id
      AND items_table.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their own accounts"
  ON accounts_table
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM items_table
      WHERE items_table.id = accounts_table.item_id
      AND items_table.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own accounts"
  ON accounts_table
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM items_table
      WHERE items_table.id = accounts_table.item_id
      AND items_table.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their own accounts"
  ON accounts_table
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM items_table
      WHERE items_table.id = accounts_table.item_id
      AND items_table.user_id = auth.uid()
    )
  );

-- Transactions policies
-- Users can only access transactions that belong to them
CREATE POLICY "Users can view their own transactions"
  ON transactions_table
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own transactions"
  ON transactions_table
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own transactions"
  ON transactions_table
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own transactions"
  ON transactions_table
  FOR DELETE
  USING (auth.uid() = user_id);

-- Refresh jobs policies
-- Users can only access their own refresh jobs
CREATE POLICY "Users can view their own refresh jobs"
  ON refresh_jobs
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own refresh jobs"
  ON refresh_jobs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own refresh jobs"
  ON refresh_jobs
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own refresh jobs"
  ON refresh_jobs
  FOR DELETE
  USING (auth.uid() = user_id);

-- Link events policies
-- Users can only access their own link events
CREATE POLICY "Users can view their own link events"
  ON link_events_table
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own link events"
  ON link_events_table
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Plaid API events policies
-- Users can only access their own API events
CREATE POLICY "Users can view their own API events"
  ON plaid_api_events_table
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own API events"
  ON plaid_api_events_table
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Institutions table policies
-- This is reference data (list of banks) that all authenticated users can read
-- Only backend services (via service role) can modify
ALTER TABLE institutions_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view institutions"
  ON institutions_table
  FOR SELECT
  TO authenticated
  USING (true);

-- Only service role can insert/update/delete institutions
-- These operations should only happen via backend Edge Functions
CREATE POLICY "Service role can insert institutions"
  ON institutions_table
  FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "Service role can update institutions"
  ON institutions_table
  FOR UPDATE
  TO service_role
  USING (true);

CREATE POLICY "Service role can delete institutions"
  ON institutions_table
  FOR DELETE
  TO service_role
  USING (true);
