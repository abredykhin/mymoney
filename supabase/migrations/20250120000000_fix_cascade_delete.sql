-- Fix foreign key constraints to enable proper cascade deletion
-- This allows users to be deleted from auth.users without constraint violations

-- Drop the existing foreign key constraint on transactions_table.user_id
ALTER TABLE transactions_table
DROP CONSTRAINT IF EXISTS transactions_table_user_id_fkey;

-- Re-add with CASCADE delete
ALTER TABLE transactions_table
ADD CONSTRAINT transactions_table_user_id_fkey
FOREIGN KEY (user_id)
REFERENCES profiles_table(id)
ON DELETE CASCADE;

-- Note: link_events_table and plaid_api_events_table have user_id columns
-- but no foreign key constraints, so they won't block deletion.
-- We should add constraints for data integrity:

-- Add foreign key to link_events_table.user_id (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'link_events_table_user_id_fkey'
  ) THEN
    ALTER TABLE link_events_table
    ADD CONSTRAINT link_events_table_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES profiles_table(id)
    ON DELETE CASCADE;
  END IF;
END $$;

-- Add foreign key to plaid_api_events_table.user_id (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'plaid_api_events_table_user_id_fkey'
  ) THEN
    ALTER TABLE plaid_api_events_table
    ADD CONSTRAINT plaid_api_events_table_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES profiles_table(id)
    ON DELETE CASCADE;
  END IF;
END $$;
