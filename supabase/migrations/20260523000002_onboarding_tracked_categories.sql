-- Add user-selected flexible spending categories to profile
-- These are set during onboarding Step 5 ("Where does the rest go?")

ALTER TABLE profiles_table
  ADD COLUMN IF NOT EXISTS tracked_spending_categories text[] NOT NULL DEFAULT '{}';
