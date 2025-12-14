# Migration Plan: MyMoney (Bablo) -> Supabase (All-In)

**Target Agent:** Any LLM (Claude, Gemini, etc.)
**Objective:** Migrate legacy Node.js/Express backend to a serverless architecture using Supabase (Auth, Database, Edge Functions) and eliminate all infrastructure management.

---

## 🎯 Project Goals & Constraints

### Primary Goals
1. **Zero DevOps**: No servers, containers, or infrastructure to manage
2. **Cost Optimization**: Stay within Supabase Free tier ($0/month)
3. **Simplicity**: Minimize moving parts and dependencies

### Scale & Context (IMPORTANT for LLMs)
- **User base**: Personal app, <100 users expected
- **Transaction volume per sync**: ~300 transactions (6 months of history per account)
- **Sync frequency**: On-demand (via webhook) + optional daily scheduled sync
- **Data size**: ~50MB database for years of financial data

**⚠️ DO NOT suggest Bull/Redis queues or Docker workers** - this scale doesn't require them!

### Migration Status
- **User migration**: NOT NEEDED (only test accounts in legacy DB)
- **Session migration**: NOT NEEDED (Supabase Auth replaces custom sessions)
- **Data migration**: Only institutions table needs migration from DigitalOcean

---

## 🏗️ Architecture Overview

| Component | Legacy (Node.js) | Target (Supabase) | Rationale |
| :--- | :--- | :--- | :--- |
| **Runtime** | Node.js (Express) | Deno (Supabase Edge Functions) | Serverless, no infrastructure |
| **Database** | PostgreSQL (DigitalOcean) | Supabase PostgreSQL + RLS | Managed, free tier available |
| **Auth** | Custom (`users`/`sessions` tables) | Supabase Auth (GoTrue) | JWT tokens, built-in session management |
| **Queue/Jobs** | Bull + Redis | ~~NOT NEEDED~~ | Direct webhook → sync works (see below) |
| **Background Tasks** | Bull queue workers | `ctx.waitUntil()` in Edge Functions | For non-blocking webhook responses |
| **Plaid Client** | `plaid` (npm) | `npm:plaid` (via Deno) | Same SDK, different import syntax |
| **Deployment** | Docker / Droplet | `supabase functions deploy` | Zero DevOps |

---

## 🚫 Common Misconceptions (READ THIS!)

### ❌ "You need Bull/Redis for background jobs"
**FALSE for this project!** Here's why:
- **Scale**: ~300 transactions per sync = ~7 seconds total
- **Network I/O**: Doesn't count toward Edge Function CPU limits (see below)
- **Reliability**: Plaid webhooks are reliable; if missed, user can manually refresh
- **Complexity**: Bull/Redis adds unnecessary infrastructure

### ❌ "You need a Docker worker for syncing"
**FALSE!** Edge Functions can handle the sync:
- **Timeout math**:
  - Plaid API calls: ~4.5s wall-clock (network I/O, ~0.5s CPU)
  - Database batch insert: ~2s wall-clock (~0.5s CPU)
  - Total: ~7s wall-clock, ~1s CPU (well within limits)
- **Free tier limits**: 50s CPU, 150s wall-clock - plenty of headroom

### ❌ "waitUntil doesn't help with timeouts"
**NUANCED**: `ctx.waitUntil()` doesn't extend timeout, BUT:
- It allows webhook to return 200 OK immediately
- Network I/O (Plaid API, DB queries) doesn't count toward CPU timeout
- Only compute (parsing, transforming data) counts toward CPU limit

### 🔑 Critical Understanding: Network I/O vs CPU Time

Supabase Edge Functions have TWO timeout limits:
- **CPU time**: 50s (free), 200s (pro) - actual computation only
- **Wall-clock time**: 150s (free), 400s (pro) - total elapsed time

**Network I/O does NOT count toward CPU time!**

```typescript
// This sync operation breakdown:
const response = await plaid.transactionsSync(); // Network I/O - doesn't count!
const parsed = JSON.parse(response);              // CPU time - counts!
await supabase.from('transactions').insert(data); // Network I/O - doesn't count!
```

For our ~300 transaction sync:
- Wall-clock: ~7 seconds (mostly waiting on network)
- CPU time: ~1 second (parsing, data transformation)
- ✅ Well within limits!

---

## 📋 Implementation Phases

### Phase 1: Database & Project Initialization
*Goal: Replicate the schema in Supabase and prepare the local dev environment.*

**Important: Supabase Project Location & Setup**
To maintain a clean monorepo structure, all Supabase-related code (migrations, Edge Functions, configuration) should reside within a dedicated `supabase/` subdirectory.

**You (the User) will perform these initial commands:**

1.  **Create the `supabase/` directory in your project root (`/Users/abredykhin/ws/mymoney/`):**
    ```bash
    mkdir supabase
    ```
2.  **Navigate into this new directory:**
    ```bash
    cd supabase
    ```
3.  **Initialize the Supabase project:**
    ```bash
    supabase init
    ```
    This will create the necessary `config.toml`, `migrations/`, `functions/` (for Edge Functions), and `seed.sql` files/directories *inside* your `supabase/` folder.

Your project structure will then look like this:
```
/Users/abredykhin/ws/mymoney/
├───server/
├───ios/
├───database/
└───supabase/               # <-- NEW: All Supabase code goes here
    ├───config.toml
    ├───migrations/         # Migrations (SQL files) will be here
    ├───functions/          # Edge Functions (Deno .ts files) will be here
    └───... (other supabase cli generated files)
```

**After you have performed the above steps and `supabase init` has completed, the Agent (me) can proceed with the following:**

1.  **Initialize Local Project**
    *   **Action:** Verify `supabase/config.toml` exists.
    *   **Context:** `supabase/config.toml` and `supabase/migrations/` are now present.
2.  **Schema Migration**
    *   **Action:** Convert `database/create.sql` into a Supabase migration file.
    *   **LLM Instruction:** Read `database/create.sql`. Identify tables that conflict with Supabase (e.g., `users` table might conflict with `auth.users`).
    *   **Gotcha:** We should **not** recreate a custom `users` table for auth credentials. We should rename the existing `users_table` to `profiles` or `public.users` and link it to `auth.users` via a trigger on user creation.
3.  **Row Level Security (RLS)**
    *   **Action:** Enable RLS on all tables.
    *   **LLM Instruction:** Generate RLS policies.
        *   `profiles`: Users can read/update their own row.
        *   `items`, `accounts`, `transactions`: Users can read where `user_id = auth.uid()`.
    *   **Warning:** Do not forget to `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`.

### Phase 2: Authentication Replacement
*Goal: Remove custom auth code and rely on Supabase Auth (JWT-based).*

#### Key Changes
- ❌ **Remove**: `users_table` (passwords), `sessions_table` (tokens)
- ✅ **Use**: Supabase Auth (`auth.users` + JWT tokens)
- ✅ **Add**: `profiles_table` linked to `auth.users` via trigger

#### How Authentication Works in Supabase

**Client Side (iOS):**
```swift
import Supabase

// Initialize client
let client = SupabaseClient(
  supabaseURL: URL(string: "https://[project].supabase.co")!,
  supabaseKey: "[anon-key]"
)

// Sign up
try await client.auth.signUp(email: email, password: password)
// This automatically creates profile via trigger (see migration)

// Sign in
let session = try await client.auth.signIn(email: email, password: password)
// session.accessToken is a JWT - automatically included in requests
```

**Server Side (Edge Functions):**

Edge Functions **automatically** receive the user from the `Authorization` header:

```typescript
// supabase/functions/my-function/index.ts
import { createClient } from '@supabase/supabase-js'

Deno.serve(async (req) => {
  // Get user from JWT (handled automatically by Supabase)
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    {
      global: {
        headers: { Authorization: req.headers.get('Authorization')! }
      }
    }
  )

  // This returns the authenticated user from JWT
  const { data: { user }, error } = await supabase.auth.getUser()

  if (error || !user) {
    return new Response('Unauthorized', { status: 401 })
  }

  // Now you have user.id (UUID) - use it for queries!
  const { data } = await supabase
    .from('items')
    .select('*')
    // RLS automatically filters by user.id = auth.uid()

  return new Response(JSON.stringify(data))
})
```

**Do you need to check auth manually?**
- ❌ **NO** if you're using `supabase.from()` queries - RLS handles it automatically
- ✅ **YES** if you need the user ID for custom logic (e.g., passing to Plaid API)

#### Migration Tasks

1.  **Backend Cleanup**
    *   **Action:** Archive `server/controllers/users.js` and `server/controllers/sessions.js` - no longer needed
    *   **Reason:** Supabase Auth handles signup, login, password reset, email verification automatically
    *   **LLM Instruction:** When porting routes, ignore any code related to `bcrypt`, password hashing, or session token generation

2.  **iOS Client Update**
    *   **Action:** Replace `AuthManager` with Supabase Auth SDK
    *   **Old way**: `POST /users/login` → custom session token → store in Keychain
    *   **New way**: `client.auth.signIn()` → JWT access token → automatically managed by SDK
    *   **Gotcha:** Supabase SDK handles token refresh automatically - no manual expiry checks needed!

### Phase 3: Edge Functions (The Core Logic)
*Goal: Port business logic to Deno.*

#### 3.0 CRITICAL: Fix Database Batch Insert Inefficiency FIRST

**⚠️ MUST DO BEFORE MIGRATION!**

The current implementation in `server/db/queries/transactions.js:15-106` is critically inefficient:

```javascript
// CURRENT (BAD): Individual INSERT for each transaction
for (const transaction of transactions) {
  await client.query(INSERT_QUERY, values);  // 300 round-trips!
}
```

**Problem**: For 300 transactions, this makes 300 separate database queries. In Edge Functions with network latency to Supabase database, this could take 20-30+ seconds.

**Solution**: Batch insert with single query:

```typescript
// FIXED (GOOD): Single batch INSERT
const values = transactions.map((t, i) =>
  `($${i*15+1}, $${i*15+2}, ..., $${i*15+15})`
).join(',');

await client.query(`
  INSERT INTO transactions_table (account_id, amount, ...)
  VALUES ${values}
  ON CONFLICT (transaction_id) DO UPDATE SET ...
`, flattenedValues);
```

**This reduces 300 queries → 1 query, cutting database time from ~20s → ~2s**

#### 3.1 Function: `plaid-link-token`
*   **Source:** `server/routes/linkTokens.js`
*   **Task:** Create an Edge Function that generates Plaid Link tokens for connecting bank accounts
*   **Auth:** Get `user.id` from JWT via `supabase.auth.getUser()` (see Phase 2)
*   **Logic:**
    ```typescript
    const { data: { user } } = await supabase.auth.getUser();
    const linkToken = await plaidClient.linkTokenCreate({
      user: { client_user_id: user.id },
      // ... other config
    });
    return new Response(JSON.stringify({ link_token: linkToken.link_token }));
    ```

#### 3.2 Function: `plaid-webhook`
*   **Source:** `server/routes/webhook.js`
*   **Task:** Handle incoming webhooks from Plaid (SYNC_UPDATES_AVAILABLE, etc.)
*   **Architecture:** Direct sync approach (no queue needed)
    ```typescript
    Deno.serve(async (req, ctx) => {
      const { webhook_code, item_id } = await req.json();

      if (webhook_code === 'SYNC_UPDATES_AVAILABLE') {
        // Use waitUntil to not block 200 OK response
        ctx.waitUntil(syncTransactions(item_id));
      }

      return new Response('OK', { status: 200 });
    });
    ```
*   **Why no queue?** Sync takes ~7s, webhook returns immediately via `waitUntil()`, no Bull/Redis needed

#### 3.3 Function: `sync-transactions`
*   **Source:** `server/controllers/transactions.js` & `server/controllers/dataRefresher.js`
*   **Task:** Fetch transactions from Plaid and batch upsert into Supabase
*   **Complexity:** MEDIUM (was HIGH, but fixed with batch inserts)

**Architecture:**
```typescript
async function syncTransactions(itemId: string) {
  // 1. Get access token and cursor from database
  const { access_token, cursor } = await getItemDetails(itemId);

  let allAdded = [], allModified = [], allRemoved = [];
  let currentCursor = cursor;
  let hasMore = true;

  // 2. Fetch from Plaid (network I/O - doesn't count toward CPU limit!)
  while (hasMore) {
    const response = await plaidClient.transactionsSync({
      access_token,
      cursor: currentCursor,
      count: 100,
    });

    allAdded.push(...response.data.added);
    allModified.push(...response.data.modified);
    allRemoved.push(...response.data.removed);
    currentCursor = response.data.next_cursor;
    hasMore = response.data.has_more;
  }

  // 3. Batch upsert (CRITICAL: use batch insert, not individual queries!)
  await batchUpsertTransactions([...allAdded, ...allModified]);
  await batchDeleteTransactions(allRemoved);
  await updateCursor(itemId, currentCursor);
}
```

**Performance Expectations:**
- Plaid API: 3 pages × 1.5s = ~4.5s (network I/O)
- Batch insert: ~2s (network I/O)
- Total: ~7s wall-clock, ~1s CPU
- ✅ Well within Edge Function limits

**Gotchas:**
*   **MUST use batch inserts** - see section 3.0 above
*   **Rate Limits:** Handle Plaid 429 errors with exponential backoff
*   **Cursor Management:** Always save cursor, even on partial failure
*   **User ID mapping:** For new transactions, set `user_id` field (used by RLS)

**When to use service_role key:**
```typescript
// For webhook functions that don't have user context
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, // Bypasses RLS
)
```

### Phase 4: Read-Only APIs
*Goal: Port simple data fetching routes.*

**Two Approaches:**

**Option A: Edge Functions (Recommended for MVP)**
Port existing routes 1:1 as Edge Functions:
- `/budget/totalBalance` → `supabase/functions/total-balance`
- `/transactions/recent` → `supabase/functions/recent-transactions`
- `/transactions/byCategory` → `supabase/functions/transactions-by-category`

```typescript
// Example: supabase/functions/total-balance/index.ts
Deno.serve(async (req) => {
  const supabase = createClient(/* with auth header */);
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) return new Response('Unauthorized', { status: 401 });

  // RLS automatically filters by user.id
  const { data } = await supabase
    .from('accounts')
    .select('current_balance')
    .eq('hidden', false);

  const total = data.reduce((sum, acc) => sum + acc.current_balance, 0);
  return new Response(JSON.stringify({ total }));
});
```

**Option B: Direct Database Access (Future Optimization)**
Since RLS is enabled, iOS app can query Supabase directly:
```swift
// No Edge Function needed!
let accounts = try await supabase
  .from("accounts")
  .select()
  .eq("hidden", false)
  .execute()
```

**Recommendation:** Start with Option A (Edge Functions) to minimize iOS changes, migrate to Option B later for better performance.

### Phase 5: Scheduled Sync (Optional)
*Goal: Auto-refresh transactions daily without user action.*

**Why pg_cron?**
- Built into Supabase (no external service needed)
- Can trigger Edge Functions on schedule
- Perfect for daily/hourly background tasks

**Setup via Supabase Dashboard:**

1. Go to Database → Cron Jobs
2. Create job:
```sql
-- Run every day at 6 AM UTC
SELECT cron.schedule(
  'daily-transaction-sync',
  '0 6 * * *',
  $$
  SELECT
    net.http_post(
      url := 'https://[project-ref].supabase.co/functions/v1/scheduled-sync',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
      ),
      body := jsonb_build_object('trigger', 'cron')
    );
  $$
);
```

3. Create Edge Function to handle scheduled sync:
```typescript
// supabase/functions/scheduled-sync/index.ts
Deno.serve(async (req) => {
  // Verify service role (only cron can call this)
  const authHeader = req.headers.get('Authorization');
  // ... validation

  // Get all active items and sync them
  const items = await getAllActiveItems();
  for (const item of items) {
    await syncTransactions(item.plaid_item_id);
  }

  return new Response('Sync completed');
});
```

**Alternative:** User-triggered refresh button in iOS app (simpler, no cron needed)

---

## ⚠️ Critical Warnings for LLM Execution

### 1. DO NOT Suggest These (Common LLM Mistakes)
- ❌ Bull/Redis queues (not needed for this scale)
- ❌ Docker workers or separate containers (Edge Functions handle it)
- ❌ User/session migration logic (only test accounts exist)
- ❌ `sessions_table` or custom auth (Supabase Auth replaces it)
- ❌ Individual database INSERT statements (MUST use batch inserts)

### 2. Deno/TypeScript Syntax
```typescript
// ✅ CORRECT
import { Configuration, PlaidApi } from 'npm:plaid@31.1.0';
import { createClient } from 'jsr:@supabase/supabase-js@2';

// ❌ WRONG
const plaid = require('plaid');  // require() doesn't exist in Deno!
```

### 3. Environment Variables
```typescript
// ✅ CORRECT
const plaidClientId = Deno.env.get('PLAID_CLIENT_ID')!;

// ❌ WRONG
const plaidClientId = process.env.PLAID_CLIENT_ID;  // process.env doesn't exist in Deno!
```

**Setting secrets in Supabase:**
```bash
# Local development
echo "PLAID_CLIENT_ID=your-id" >> supabase/.env.local

# Production
supabase secrets set PLAID_CLIENT_ID=your-id
```

### 4. Authentication in Edge Functions

**For user-authenticated endpoints:**
```typescript
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_ANON_KEY')!,
  {
    global: {
      headers: { Authorization: req.headers.get('Authorization')! }
    }
  }
);

const { data: { user } } = await supabase.auth.getUser();
if (!user) return new Response('Unauthorized', { status: 401 });
```

**For webhooks/cron (no user context):**
```typescript
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!  // Bypasses RLS
);
```

### 5. CORS Handling
```typescript
// Handle CORS for browser requests (if needed)
if (req.method === 'OPTIONS') {
  return new Response('ok', {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
      'Access-Control-Allow-Headers': 'authorization, content-type',
    }
  });
}
```

### 6. Database Operations

**❌ NEVER do this:**
```typescript
for (const transaction of transactions) {
  await supabase.from('transactions').insert(transaction);  // 300 queries!
}
```

**✅ ALWAYS do this:**
```typescript
await supabase.from('transactions').insert(transactions);  // 1 query!
```

### 7. Context Awareness
Before writing code:
- Read `database/create.sql` or migration files for schema
- Read `server/package.json` for Plaid version
- Read existing controller files (`server/controllers/*.js`) for business logic
- Check `supabase/migrations/*.sql` for current Supabase schema

### 8. Error Handling
```typescript
try {
  const response = await plaidClient.transactionsSync({...});
  // ... process
} catch (error) {
  if (error.response?.status === 429) {
    // Rate limit - retry with backoff
    await new Promise(resolve => setTimeout(resolve, 5000));
    return syncTransactions(itemId); // Retry
  }

  console.error('Sync failed:', error);
  throw error; // Let Edge Function runtime handle it
}
```

### 9. Type Safety
```typescript
// Define interfaces based on database schema
interface Transaction {
  id: number;
  account_id: number;
  user_id: string;  // UUID from auth.users
  amount: number;
  date: string;
  transaction_id: string;
  // ... other fields
}

interface PlaidItem {
  id: number;
  user_id: string;
  plaid_access_token: string;
  plaid_item_id: string;
  transactions_cursor: string | null;
}
```

---

## 📊 Cost Analysis (Supabase Free Tier)

| Resource | Free Tier Limit | Expected Usage | Status |
|----------|----------------|----------------|--------|
| Database | 500 MB | ~50 MB (years of data) | ✅ Safe |
| Bandwidth | 2 GB/month | ~200 MB/month | ✅ Safe |
| Edge Function Invocations | 500K/month | ~1-2K/month | ✅ Safe |
| Edge Function CPU | 50 seconds | ~1s per sync | ✅ Safe |
| Storage | 1 GB | Not used | ✅ Safe |

**Conclusion:** You'll comfortably stay within free tier for <100 users.

---

## 🎯 Implementation Checklist

### Before Migration
- [ ] Fix batch insert inefficiency in `server/db/queries/transactions.js`
- [ ] Test batch insert locally with current Node.js backend
- [ ] Export institutions data from DigitalOcean (only table that needs migration)

### Phase 1: Database
- [x] Create Supabase project
- [x] Run initial schema migration (`20250101000000_initial_schema.sql`)
- [x] Enable RLS and policies (`20250101000001_enable_rls.sql`)
- [ ] Import institutions data

### Phase 2: Authentication
- [x] Create Edge Function for signup (optional - can use Supabase Auth directly)
- [x] Update iOS app to use Supabase Auth SDK
- [x] Implement Sign in with Apple via Supabase
- [x] Archive legacy auth code (users.js, sessions.js)
- [ ] Test login/signup/logout flow end-to-end

### Phase 3: Core Functions
- [x] Create `plaid-link-token` Edge Function
- [x] Create `plaid-webhook` Edge Function
- [x] Create `sync-transactions` Edge Function (with batch inserts!)
- [ ] Test webhook → sync flow locally
- [ ] Deploy functions to production

### Phase 4: Read APIs
- [ ] Port `/budget/totalBalance`
- [ ] Port `/transactions/recent`
- [ ] Port other read endpoints as needed

### Phase 5: Optional
- [ ] Set up pg_cron for daily scheduled sync
- [ ] Add manual refresh button in iOS app
- [ ] Monitor Edge Function logs

---

## 🛠️ Step-by-Step Prompting Strategy (for User)

When asking an LLM to perform a task, use this pattern:

> "I want to implement **[Step Name]** from `migrate-to-supabase.md`.
>
> 1. Read **[Source File(s)]**.
> 2. Read **[Target/Context File(s)]** (e.g., schema, existing migration).
> 3. Generate the file **[Output File Path]**.
> 4. Ensure you handle **[Specific Gotcha from Plan]**."

**Example:**
> "I want to implement **Phase 3.1 (plaid-link-token)** from `migrate-to-supabase.md`.
>
> 1. Read `server/routes/linkTokens.js` to understand current implementation.
> 2. Read `supabase/migrations/20250101000000_initial_schema.sql` for schema.
> 3. Generate `supabase/functions/plaid-link-token/index.ts`.
> 4. Ensure you use `supabase.auth.getUser()` for authentication (see Phase 2 section)."

---

## 📚 Quick Reference

### Key Differences: Legacy vs Supabase

| Aspect | Legacy | Supabase |
|--------|--------|----------|
| Get user ID | `req.user.id` (from session middleware) | `await supabase.auth.getUser()` |
| Check auth | Custom session validation | JWT token in Authorization header |
| Database query | `db.query('SELECT ...', [userId])` | `supabase.from('table').select()` (RLS filters) |
| Background job | Bull queue worker | `ctx.waitUntil()` in Edge Function |
| Batch insert | 300 individual INSERTs (BAD) | 1 batch INSERT (GOOD) |

### Common Queries

**Get user's items:**
```typescript
// Supabase (RLS filters automatically)
const { data } = await supabase.from('items').select('*');

// Legacy (manual filtering)
const items = await db.query('SELECT * FROM items WHERE user_id = $1', [userId]);
```

**Create transaction:**
```typescript
// Supabase
await supabase.from('transactions_table').insert({
  account_id,
  user_id: user.id,  // Must set explicitly for RLS
  amount,
  // ...
});
```

---

## 🔍 Troubleshooting

### "Edge Function timeout"
- Check if you're using batch inserts (not individual queries)
- Verify network I/O is not being counted as CPU time
- Add logging to measure actual CPU vs wall-clock time

### "Unauthorized" errors
- Verify Authorization header is passed to supabase client
- Check if RLS policies are correctly configured
- Use service_role key for webhooks (no user context)

### "Plaid rate limit"
- Add exponential backoff for 429 errors
- Consider adding delay between pages (not usually needed)

### "Transaction not found"
- Ensure `user_id` is set on new transactions (for RLS)
- Check that accounts view properly joins with items table

---

## 📖 Additional Resources

- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [Row Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [Deno Deploy Limits](https://deno.com/deploy/docs/pricing-and-limits)
- [Plaid API Sync Documentation](https://plaid.com/docs/api/products/transactions/#transactionssync)
