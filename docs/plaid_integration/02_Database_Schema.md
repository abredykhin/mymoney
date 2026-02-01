## 2. Database Schema Changes

### 2.1 Create `recurring_streams_table`

Replace `budget_items_table` with a new table that stores Plaid's native recurring stream data:

```sql
CREATE TABLE recurring_streams_table (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    item_id INTEGER REFERENCES items_table(id) ON DELETE CASCADE,
    account_id INTEGER REFERENCES accounts_table(id) ON DELETE CASCADE,

    -- Plaid stream identifiers (nullable for manual streams)
    plaid_stream_id TEXT,

    -- Stream details
    description TEXT NOT NULL,
    merchant_name TEXT,
    personal_finance_category TEXT,  -- Matches existing transactions_table column (stores PRIMARY value)
    personal_finance_subcategory TEXT,  -- Matches existing transactions_table column (stores DETAILED value)
    frequency TEXT NOT NULL, -- WEEKLY, SEMI_MONTHLY, MONTHLY, ANNUALLY, etc.

    -- Financial data
    average_amount NUMERIC(28,10) NOT NULL,
    last_amount NUMERIC(28,10),
    monthly_amount NUMERIC(28,10) NOT NULL, -- Normalized to monthly
    iso_currency_code TEXT DEFAULT 'USD',

    -- Stream metadata
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    status TEXT NOT NULL, -- MATURE, EARLY_DETECTION, manual
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    first_date DATE,
    last_date DATE,
    predicted_next_date DATE,
    is_user_modified BOOLEAN DEFAULT FALSE,

    -- User overrides
    user_marked_recurring BOOLEAN DEFAULT NULL, -- NULL = use Plaid, TRUE = force recurring, FALSE = force non-recurring
    is_excluded BOOLEAN DEFAULT FALSE, -- User wants to exclude from budget calc

    -- Manual stream support (MVP: simple pattern matching)
    is_manual BOOLEAN DEFAULT FALSE, -- TRUE if user created this stream, FALSE if from Plaid
    match_pattern TEXT, -- Simple substring pattern for matching transactions (e.g., "NETFLIX")

    -- Sync metadata
    last_synced_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Ensure manual streams have a match pattern
    CHECK (
        (is_manual = FALSE AND plaid_stream_id IS NOT NULL) OR
        (is_manual = TRUE AND match_pattern IS NOT NULL)
    )
);

-- Indexes
CREATE INDEX idx_recurring_streams_user_id ON recurring_streams_table(user_id);
CREATE INDEX idx_recurring_streams_item_id ON recurring_streams_table(item_id);
CREATE INDEX idx_recurring_streams_account_id ON recurring_streams_table(account_id);
CREATE INDEX idx_recurring_streams_type ON recurring_streams_table(user_id, type, is_active);
CREATE INDEX idx_recurring_streams_is_manual ON recurring_streams_table(user_id, is_manual);

-- Unique constraints (handling nullable plaid_stream_id properly)
CREATE UNIQUE INDEX idx_unique_plaid_streams
ON recurring_streams_table(user_id, plaid_stream_id)
WHERE plaid_stream_id IS NOT NULL AND is_manual = FALSE;

CREATE UNIQUE INDEX idx_unique_manual_streams
ON recurring_streams_table(user_id, match_pattern)
WHERE is_manual = TRUE;

-- RLS Policies
ALTER TABLE recurring_streams_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own recurring streams"
    ON recurring_streams_table FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own recurring streams"
    ON recurring_streams_table FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own recurring streams"
    ON recurring_streams_table FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own recurring streams"
    ON recurring_streams_table FOR DELETE
    USING (auth.uid() = user_id);
```

### 2.2 Create `recurring_stream_transactions_table`

Junction table linking transactions to their recurring streams:

```sql
CREATE TABLE recurring_stream_transactions_table (
    id SERIAL PRIMARY KEY,
    stream_id INTEGER NOT NULL REFERENCES recurring_streams_table(id) ON DELETE CASCADE,
    transaction_id INTEGER NOT NULL REFERENCES transactions_table(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(stream_id, transaction_id)
);

CREATE INDEX idx_stream_transactions_stream ON recurring_stream_transactions_table(stream_id);
CREATE INDEX idx_stream_transactions_transaction ON recurring_stream_transactions_table(transaction_id);
CREATE INDEX idx_stream_tx_lookup ON recurring_stream_transactions_table(transaction_id, stream_id);

ALTER TABLE recurring_stream_transactions_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their stream transaction links"
    ON recurring_stream_transactions_table FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM recurring_streams_table rs
        WHERE rs.id = stream_id AND rs.user_id = auth.uid()
    ));
```

### 2.3 Update `items_table`

Add a flag to track when historical transaction sync is complete:

```sql
ALTER TABLE items_table
ADD COLUMN historical_sync_complete BOOLEAN DEFAULT FALSE,
ADD COLUMN historical_completed_at TIMESTAMPTZ;

CREATE INDEX idx_items_historical_complete ON items_table(historical_sync_complete);
```

**Why this matters:** Plaid requires historical transaction data to be fully loaded before we can call `/transactions/recurring/get`. We need to track when this happens.

### 2.4 Update `transactions_table`

Add a computed field to track recurring status:

```sql
ALTER TABLE transactions_table ADD COLUMN is_recurring BOOLEAN DEFAULT FALSE;
CREATE INDEX idx_transactions_recurring ON transactions_table(user_id, is_recurring, date);

-- Performance index for variable_transactions view
CREATE INDEX idx_transactions_non_recurring
ON transactions_table(user_id, date)
WHERE is_recurring = FALSE OR is_recurring IS NULL;
```

### 2.5 Update `variable_transactions` View

Redefine to use the new recurring streams data:

```sql
CREATE OR REPLACE VIEW variable_transactions AS
SELECT t.*
FROM transactions t
WHERE t.is_recurring = FALSE
   OR t.is_recurring IS NULL;

ALTER VIEW variable_transactions SET (security_invoker = true);
```
