-- This trigger updates the value in the updated_at column. It is used in the tables below to log
-- when a row was last updated.
DO
$$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anton') THEN
        CREATE ROLE anton WITH LOGIN CREATEDB;
    END IF;
END
$$;

CREATE DATABASE mymoney;
GRANT ALL PRIVILEGES ON DATABASE mymoney TO anton;
ALTER DATABASE mymoney OWNER TO anton;
\c mymoney anton

CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- USERS
-- This table is used to store the users of our application. The view returns the same data as the
-- table, we're just creating it to follow the pattern used in other tables.

CREATE TABLE users_table
(
  id SERIAL PRIMARY KEY,
  username text UNIQUE NOT NULL,
  password text NOT NULL,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

CREATE TRIGGER users_updated_at_timestamp
BEFORE UPDATE ON users_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW users
AS
  SELECT
    id,
    username,
    password,
    created_at,
    updated_at
  FROM
    users_table;


-- SESSIONS
-- This table is used to store user sessions.
CREATE TYPE session_token_status AS ENUM ('valid', 'expired');

CREATE TABLE sessions_table
(
  session_id SERIAL PRIMARY KEY,  
  token text UNIQUE NOT NULL,
  created_at timestamptz default now(),
  user_id integer REFERENCES users_table(id) ON DELETE CASCADE,
  status session_token_status default 'valid'
);

-- ITEMS
-- This table is used to store the items associated with each user. The view returns the same data
-- as the table, we're just using both to maintain consistency with our other tables. For more info
-- on the Plaid Item schema, see the docs page: https://plaid.com/docs/#item-schema

CREATE TABLE items_table
(
  id SERIAL PRIMARY KEY,
  user_id integer REFERENCES users_table(id) ON DELETE CASCADE,
  bank_name text,
  plaid_access_token text UNIQUE NOT NULL,
  plaid_item_id text UNIQUE NOT NULL,
  plaid_institution_id text NOT NULL,
  status text NOT NULL,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  transactions_cursor text,
  is_active boolean NOT NULL DEFAULT TRUE
);

CREATE TRIGGER items_updated_at_timestamp
BEFORE UPDATE ON items_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW items
AS
  SELECT
    id,
    plaid_item_id,
    user_id,
    plaid_access_token,
    plaid_institution_id,
    status,
    created_at,
    updated_at,
    transactions_cursor,
    bank_name
  FROM
    items_table;


CREATE TABLE institutions_table
(
  id SERIAL PRIMARY KEY,
  institution_id text UNIQUE NOT NULL,
  name text NOT NULL,
  primary_color text,
  url text,
  logo text,
  updated_at timestamptz default now()
);

CREATE TRIGGER institutions_updated_at_timestamp
BEFORE UPDATE ON institutions_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW institutions
AS
  SELECT
    id,
    institution_id,
    name,
    primary_color,
    url,
    logo,
    updated_at
  FROM
    institutions_table;    


-- -- ASSETS
-- -- This table is used to store the assets associated with each user. The view returns the same data
-- -- as the table, we're just using both to maintain consistency with our other tables.

CREATE TABLE assets_table
(
  id SERIAL PRIMARY KEY,
  user_id integer REFERENCES users_table(id) ON DELETE CASCADE,
  value numeric(28,2),
  description text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

CREATE TRIGGER assets_updated_at_timestamp
BEFORE UPDATE ON assets_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW assets
AS
  SELECT
    id,
    user_id,
    value,
    description,
    created_at,
    updated_at
  FROM
    assets_table;


-- ACCOUNTS
-- This table is used to store the accounts associated with each item. The view returns all the
-- data from the accounts table and some data from the items view. For more info on the Plaid
-- Accounts schema, see the docs page:  https://plaid.com/docs/#account-schema

CREATE TABLE accounts_table
(
  id SERIAL PRIMARY KEY,
  item_id integer REFERENCES items_table(id) ON DELETE CASCADE,
  plaid_account_id text UNIQUE NOT NULL,
  name text NOT NULL,
  mask text NOT NULL,
  official_name text,
  current_balance numeric(28,10),
  available_balance numeric(28,10),
  iso_currency_code text,
  unofficial_currency_code text,
  type text NOT NULL,
  subtype text NOT NULL,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

CREATE TRIGGER accounts_updated_at_timestamp
BEFORE UPDATE ON accounts_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW accounts
AS
  SELECT
    a.id,
    a.plaid_account_id,
    a.item_id,
    i.plaid_item_id,
    i.user_id,
    a.name,
    a.mask,
    a.official_name,
    a.current_balance,
    a.available_balance,
    a.iso_currency_code,
    a.unofficial_currency_code,
    a.type,
    a.subtype,
    a.created_at,
    a.updated_at,
  -- Add columns from the institutions view here
    ins.name AS institution_name,
    ins.primary_color AS institution_primary_color     
  FROM
    accounts_table a
    LEFT JOIN items i ON i.id = a.item_id
-- Join with the institutions view
    LEFT JOIN institutions ins ON i.plaid_institution_id = ins.institution_id;

-- TRANSACTIONS
-- This table is used to store the transactions associated with each account. The view returns all
-- the data from the transactions table and some data from the accounts view. For more info on the
-- Plaid Transactions schema, see the docs page: https://plaid.com/docs/#transaction-schema

CREATE TABLE transactions_table
(
  id SERIAL PRIMARY KEY,
  account_id integer REFERENCES accounts_table(id) ON DELETE CASCADE,
  user_id integer REFERENCES users_table(id),
  amount numeric(28,10) NOT NULL, 
  -- ISO-4217 
  iso_currency_code text,  
  date date NOT NULL,
  -- YYYY-MM-DD
  authorized_date date,
  -- The merchant name or transaction description. Note: This is a legacy field that is not actively maintained. Use merchant_name instead for the merchant name.
  name text NOT NULL,
  -- The merchant name, as enriched by Plaid from the name field. This is typically a more human-readable version of the merchant counterparty in the transaction. For some bank transactions (such as checks or account transfers) where there is no meaningful merchant name, this value will be null.
  merchant_name text,
  logo_url text,
  website text,
  --One of: online, in store, other (transactions that relate to banks, e.g. fees or deposits.)  
  payment_channel text, 
  transaction_id text UNIQUE NOT NULL,
  personal_finance_category text,
  personal_finance_subcategory text,
  pending boolean NOT NULL,
  pending_transaction_transaction_id text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

CREATE TRIGGER transactions_updated_at_timestamp
BEFORE UPDATE ON transactions_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE VIEW transactions
AS
  SELECT
    t.id,
    t.account_id,
    t.user_id,
    t.amount,
    t.iso_currency_code,
    t.date,
    t.authorized_date,
    t.name,
    t.merchant_name,
    t.logo_url,
    t.website,
    t.payment_channel,
    t.transaction_id,
    t.personal_finance_category,
    t.personal_finance_subcategory,
    t.pending,
    t.pending_transaction_transaction_id,
    t.created_at,
    t.updated_at
  FROM
    transactions_table t;


-- The link_events_table is used to log responses from the Plaid API for client requests to the
-- Plaid Link client. This information is useful for troubleshooting.

CREATE TABLE link_events_table
(
  id SERIAL PRIMARY KEY,
  type text NOT NULL,
  user_id integer,
  link_session_id text,
  request_id text UNIQUE,
  error_type text,
  error_code text,
  status text,
  created_at timestamptz default now()
);


-- The plaid_api_events_table is used to log responses from the Plaid API for server requests to
-- the Plaid client. This information is useful for troubleshooting.

CREATE TABLE plaid_api_events_table
(
  id SERIAL PRIMARY KEY,
  item_id integer,
  user_id integer,
  plaid_method text NOT NULL,
  arguments text,
  request_id text UNIQUE,
  error_type text,
  error_code text,
  created_at timestamptz default now()
);

CREATE INDEX idx_items_plaid_item_id ON items_table(plaid_item_id);
CREATE INDEX idx_transactions_transaction_id ON transactions_table(transaction_id);
CREATE INDEX idx_sessions_token ON sessions_table(token);