#!/bin/bash

# setup_local_env.sh
# Automates the setup of a local Supabase environment with production data

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "${GREEN}Starting Local Supabase Setup...${NC}"

# 1. Check Prerequisites
if ! command -v docker &> /dev/null; then
    echo "${RED}Error: Docker is not running or not installed.${NC}"
    exit 1
fi

if ! command -v supabase &> /dev/null; then
    echo "${RED}Error: Supabase CLI is not installed.${NC}"
    echo "Install it via brew install supabase/tap/supabase"
    exit 1
fi

# 2. Dump Production Data
echo "${GREEN}Dumping production data (public schema)...${NC}"
echo "You may be asked for your database password."
supabase db dump --data-only --schema public > supabase/seed.sql

if [ $? -ne 0 ]; then
    echo "${RED}Failed to dump data. Ensure you are logged in (supabase login) and have access.${NC}"
    exit 1
fi

# 3. Start Supabase (or restart to apply seed)
echo "${GREEN}Starting local Supabase instance...${NC}"
supabase stop --no-backup # Ensure clean slate
supabase start

# 4. Create Test User via SQL (since CLI auth command might be missing)
TEST_EMAIL="test@example.com"
TEST_PASS="password"

echo "${GREEN}Creating test user ($TEST_EMAIL)...${NC}"

# SQL to create user if not exists and return ID

# SQL to create user if not exists and return ID


CREATE_USER_SQL="
WITH user_check AS (
    SELECT id FROM auth.users WHERE email = '$TEST_EMAIL'
),
inserted_user AS (
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, 
      confirmation_token, recovery_token, email_change_token_new, email_change, 
      phone_change, phone_change_token, email_change_token_current, reauthentication_token,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    )
    SELECT 
      '00000000-0000-0000-0000-000000000000',
      '5f6bb5c6-faf0-484f-aee1-23316a77ea90',
      'authenticated',
      'authenticated',
      '$TEST_EMAIL',
      crypt('$TEST_PASS', gen_salt('bf')),
      now(),
      '', '', '', '', '', '', '', '',
      '{\"provider\":\"email\",\"providers\":[\"email\"]}',
      '{}',
      now(),
      now()
    WHERE NOT EXISTS (SELECT 1 FROM user_check)
    RETURNING id
),
user_id_result AS (
    SELECT id FROM user_check
    UNION ALL
    SELECT id FROM inserted_user
),
inserted_identity AS (
    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    SELECT
      gen_random_uuid(),
      id,
      format('{\"sub\":\"%s\",\"email\":\"%s\"}', id, '$TEST_EMAIL')::jsonb,
      'email',
      '$TEST_EMAIL',
      now(),
      now(),
      now()
    FROM inserted_user
)
SELECT id FROM user_id_result;
"

# Execute and capture output (last line should be the ID)
# Using docker exec to run psql directly on the db container
# Use session_replication_role = replica to suppress triggers (like handle_new_user) 
# to prevent duplicate profile creation since seed.sql already populated it.
CREATE_USER_SQL="
SET session_replication_role = replica;
$CREATE_USER_SQL
"

USER_ID=$(echo "$CREATE_USER_SQL" | docker exec -i supabase_db_mymoney psql -U postgres -d postgres -t -A | tail -n 1) 

if [ -z "$USER_ID" ]; then
    echo "${RED}Failed to get Test User ID.${NC}"
    exit 1
fi

echo "${GREEN}Test User ID: $USER_ID${NC}"

# 5. Remap Data to Test User
echo "${GREEN}Remapping production data to Test User...${NC}"

# SQL to reassign ownership
# 1. Finds the old user ID from items_table
# 2. Reassigns Items, Transactions, Budget Items to new Test User
# 3. Copies Profile data (Income/Budget) from Old User to Test User
# 4. Cleans up Old User
REMAP_SQL="
DO \$\$
DECLARE
  test_user_id uuid := '$USER_ID';
  old_user_id uuid;
BEGIN
  -- Find the old user ID from items (assuming single user dump or we pick one)
  SELECT user_id INTO old_user_id FROM public.items_table LIMIT 1;
  
  IF old_user_id IS NOT NULL THEN
    RAISE NOTICE 'Found old user ID: %', old_user_id;

    -- 1. Reassign Items (This implicitly handles accounts permissioning via RLS)
    UPDATE public.items_table SET user_id = test_user_id WHERE user_id = old_user_id;
    
    -- 2. Reassign Transactions
    UPDATE public.transactions_table SET user_id = test_user_id WHERE user_id = old_user_id;
    
    -- 3. Reassign Budget Items
    UPDATE public.budget_items_table SET user_id = test_user_id WHERE user_id = old_user_id;
    
    -- 4. Sync Profile Data (Copy critical budget fields)
    -- We explicitly list columns to avoid overwriting ID or non-existent columns
    UPDATE public.profiles_table 
    SET 
        monthly_income = (SELECT monthly_income FROM public.profiles_table WHERE id = old_user_id),
        monthly_mandatory_expenses = (SELECT monthly_mandatory_expenses FROM public.profiles_table WHERE id = old_user_id)
    WHERE id = test_user_id;
    
    -- 5. Delete Old Profile (Optional, easier for cleanup)
    -- DELETE FROM public.profiles_table WHERE id = old_user_id;
  ELSE
    RAISE NOTICE 'No existing items found. Skipping remapping.';
  END IF;
END \$\$;
"

echo "$REMAP_SQL" | docker exec -i supabase_db_mymoney psql -U postgres -d postgres


# 6. Output Info
echo "${GREEN}Setup Complete!${NC}"
echo "---------------------------------------------------"
echo "Local API URL: $(supabase status -o json | grep 'API URL' -A 1 | tail -n 1 | awk -F: '{print $2":"$3}' | tr -d '", ')"
echo "Anon Key:     $(supabase status -o json | grep 'anon key' -A 1 | tail -n 1 | awk -F: '{print $2}' | tr -d '", ')"
echo "Test User:    $TEST_EMAIL"
echo "Test Pass:    $TEST_PASS"
echo "---------------------------------------------------"

# 7. Check for Secrets (.env)
ENV_FILE="supabase/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "${RED}WARNING: supabase/.env file not found!${NC}"
    echo "Creating a template at $ENV_FILE..."
    cat > "$ENV_FILE" << EOF
# Local Secrets for Edge Functions
# Required for Plaid and Gemini to work locally

PLAID_CLIENT_ID="replace_me"
PLAID_SECRET="replace_me"
PLAID_ENV="sandbox"
GEMINI_API_KEY="replace_me"

# Optional overrides
# PLAID_WEBHOOK_URL="http://..."
EOF
    echo "${GREEN}Created $ENV_FILE.${NC}"
    echo "⚠️  PLEASE EDIT THIS FILE with your real API keys, then restart Supabase (supabase stop && supabase start)."
else
    echo "${GREEN}Found existing secrets file at $ENV_FILE.${NC}"
fi

echo "---------------------------------------------------"
echo "IMPORTANT: Copy the Anon Key above and update your project.pbxproj script with it."
