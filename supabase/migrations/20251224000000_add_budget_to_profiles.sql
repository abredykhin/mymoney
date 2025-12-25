-- Add budget columns to profiles_table
ALTER TABLE public.profiles_table
ADD COLUMN monthly_income numeric(28,2) DEFAULT 0,
ADD COLUMN monthly_mandatory_expenses numeric(28,2) DEFAULT 0;

-- Update the profiles view to include the new columns
DROP VIEW IF EXISTS profiles;
CREATE VIEW profiles
AS
  SELECT
    id,
    username,
    monthly_income,
    monthly_mandatory_expenses,
    created_at,
    updated_at
  FROM
    profiles_table;
