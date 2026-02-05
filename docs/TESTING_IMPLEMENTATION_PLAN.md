# Edge Functions Testing - Implementation Plan (REVISED)

**Status:** ⚠️ REQUIRES MAJOR REWORK - Current tests are fundamentally flawed
**Updated:** 2026-02-04
**Previous Status:** Steps 1-6 marked complete, but review found critical issues

---

## 🤖 QUICK START FOR LLM AGENTS

**If you are an LLM agent helping to implement this plan, read this section first.**

### Core Principle (DO NOT DEVIATE)
```
TEST AGAINST REAL LOCAL SUPABASE, NOT MOCKS
```

### Decision Tree: Should I Mock This?

```
Is this Supabase database/auth?
  └─> NO MOCKING - Use real local instance (http://localhost:54321)

Is this my own utility function?
  └─> NO MOCKING - Test the real function

Is this Plaid API?
  └─> NO MOCKING - Use real Plaid sandbox (sandbox.plaid.com)
      └─> Free, deterministic, rich test data
      └─> See: https://plaid.com/docs/sandbox/

Is this Gemini API?
  └─> YES, MOCK IT - Costs money per request, rate limits

Is this some other external service with a free sandbox/test environment?
  └─> NO MOCKING - Use their sandbox/test environment

Is this some other external service without free testing?
  └─> YES, MOCK IT - But mock minimally, document why
```

### Implementation Order (Follow Sequentially)

**DO THIS FIRST:**
1. ✅ Verify `supabase start` works and note the credentials
2. ✅ Read the "What's Wrong" section to understand the problem
3. ✅ Execute Step 1A: Delete mock infrastructure
4. ✅ Execute Step 1B: Create real test utilities
5. ✅ Rewrite ONE test file as proof of concept
6. ✅ Validate it works against real database
7. ✅ Continue with remaining test files

**DO NOT:**
- ❌ Create MockQueryBuilder or MockSupabaseClient
- ❌ Add IS_LOCAL_DEV or isLocal checks to production code
- ❌ Test database operations without real database
- ❌ Skip cleanup in test teardown
- ❌ Mock your own functions

### File Locations (Absolute Paths)

```
Project root: /Users/anton/ws/mymoney/

Test utilities:
  /Users/anton/ws/mymoney/supabase/functions/_shared/test-utils.ts

Production code to clean:
  /Users/anton/ws/mymoney/supabase/functions/plaid-link-token/index.ts

Test files to rewrite:
  /Users/anton/ws/mymoney/supabase/functions/_shared/auth.test.ts
  /Users/anton/ws/mymoney/supabase/functions/_shared/plaid.test.ts
  /Users/anton/ws/mymoney/supabase/functions/_shared/recurring.test.ts
  /Users/anton/ws/mymoney/supabase/functions/create-manual-stream/index.test.ts
  /Users/anton/ws/mymoney/supabase/functions/plaid-link-token/index.test.ts
  /Users/anton/ws/mymoney/supabase/functions/update-webhooks/index.test.ts
```

### Test Template (Copy This Pattern)

```typescript
// Standard test structure - copy this for each test file

import { assertEquals, assertExists } from '../_shared/test-utils.ts';
import {
  setupTestEnvironment,
  createTestJWT,
  createTestServiceRoleClient,
  withTestData,
} from '../_shared/test-utils.ts';

// ALWAYS call this at the top
await setupTestEnvironment();

Deno.test('descriptive test name', async () => {
  await withTestData(
    // 1. SETUP: Insert real data into real database
    async () => {
      const supabase = createTestServiceRoleClient();
      const { data } = await supabase
        .from('table_name')
        .insert({ /* real data */ })
        .select()
        .single();
      return data;
    },

    // 2. CLEANUP: Always clean up (runs even if test fails)
    async (data) => {
      const supabase = createTestServiceRoleClient();
      await supabase.from('table_name').delete().eq('id', data.id);
    },

    // 3. TEST: Execute and verify against real database
    async (data) => {
      const jwt = await createTestJWT({ userId: 'test-user' });

      // Test your function
      const result = await yourFunction(data);

      // Verify in real database
      const supabase = createTestServiceRoleClient();
      const { data: verified } = await supabase
        .from('table_name')
        .select('*')
        .eq('id', result.id)
        .single();

      assertExists(verified);
      assertEquals(verified.field, expectedValue);
    }
  );
});
```

### Validation Checklist

After each step, verify:
- [ ] `supabase start` is running (check `supabase status`)
- [ ] `.env.local` exists with local Supabase credentials
- [ ] Test file imports real Supabase client (not mock)
- [ ] Tests insert real data into database
- [ ] Tests clean up data in teardown
- [ ] Tests verify results by querying real database
- [ ] No `createMockSupabaseClient()` calls in test
- [ ] No `IS_LOCAL_DEV` checks in production code

---

## 🚨 CRITICAL FINDINGS FROM CODE REVIEW

### What Was Done (Steps 1-6)

The following work was completed according to the original plan:
- ✅ Step 1: Test infrastructure setup (deno.jsonc, tasks)
- ✅ Step 2: Created 638 lines of mock utilities (`test-utils.ts`)
- ✅ Step 3: Environment setup
- ✅ Step 4: Auth module tests (426 lines) - **FUNDAMENTALLY FLAWED**
- ✅ Step 5: Plaid module tests (587 lines) - **FUNDAMENTALLY FLAWED**
- ✅ Step 6: Recurring module tests (1,145 lines) - **FUNDAMENTALLY FLAWED**
- ⚠️ Step 7: Partial - 3 test files created (409 lines total) - **FUNDAMENTALLY FLAWED**

**Total code written:** ~3,500 lines

### The Core Problem: Testing Mocks Instead of Code

**Example of what's wrong:**

```typescript
// In test-utils.ts, MockQueryBuilder.applyFilters() - 55 lines
private applyFilters(): any[] {
  let result = [...this.mockData];
  for (const filter of this.filters) {
    result = result.filter(row => {
      switch (filter.operator) {
        case 'eq': return rowValue === filter.value;
        case 'neq': return rowValue !== filter.value;
        case 'gt': return rowValue > filter.value;
        // ... etc - 50 more lines
      }
    });
  }
  // ... ordering, pagination logic
}
```

**What the tests verify:**
- ✅ The mock correctly implements `.eq()`, `.gt()`, `.ilike()`, etc.
- ✅ The mock correctly handles ordering and pagination
- ✅ The mock returns the shape of data we expect

**What the tests DO NOT verify:**
- ❌ Your SQL queries use correct syntax
- ❌ Database tables/views actually exist
- ❌ Column names are spelled correctly
- ❌ RLS (Row Level Security) policies work
- ❌ Database constraints are enforced
- ❌ Foreign key relationships work
- ❌ Your queries work with real Supabase
- ❌ JWT authentication actually validates users
- ❌ Service role permissions bypass RLS correctly

### Production Code Pollution

Found in `plaid-link-token/index.ts:56-84`:

```typescript
const isLocal = Deno.env.get('IS_LOCAL_DEV') === 'true';
let user;
let supabase;

if (isLocal) {
  console.log('⚠️  Running locally - Auth bypassed for testing');
  user = { id: 'local-test-user-123' };
} else {
  // normal production auth flow
}
```

**This is a security anti-pattern:**
- Creates a bypass mechanism in production code
- Could accidentally work in production if env var leaks
- Makes code harder to understand
- Provides false test confidence

### Why This Matters

According to [Supabase's official documentation](https://supabase.com/docs/guides/functions/unit-test):

> **Supabase recommends testing against a local instance, not mocking the client.**

The documentation shows:
- Real `createClient()` calls pointing to local Supabase
- Actual database queries in tests
- Live function invocations using `supabase functions serve`

---

## 🎯 THE CORRECT APPROACH

### Testing Philosophy (REVISED)

#### ⚠️ MOCKS ARE A LAST RESORT ⚠️

**Test against real implementations whenever possible:**

1. **ALWAYS use real local Supabase** ✅
   - Run `supabase start` for local PostgreSQL instance
   - Point tests at `http://localhost:54321`
   - Get real database behavior, RLS enforcement, constraint checking
   - Tests verify actual SQL queries work

2. **ALWAYS use real shared utilities** ✅
   - Test auth utilities with real JWT generation/validation
   - Test database helpers with real queries
   - Test data transformations with real inputs

3. **Use real sandbox environments for external APIs** ✅
   - Plaid → Use Plaid sandbox (sandbox.plaid.com)
   - Stripe → Use Stripe test mode
   - Any API with free test environment → Use it

4. **ONLY mock when absolutely necessary** ⚠️
   - Gemini API (costs money per request)
   - APIs without free sandbox
   - Network-isolated CI environments (last resort)

5. **NEVER mock:**
   - ❌ Your own Supabase client
   - ❌ Your own utility functions
   - ❌ Your own business logic
   - ❌ Database operations
   - ❌ Authentication flows
   - ❌ External APIs that have free sandboxes

### Test Layers (REVISED)

**Integration Tests** (90% of tests) ✅
- Test functions with real local Supabase instance
- Use real Plaid sandbox (sandbox.plaid.com)
- Mock only APIs without free sandboxes (Gemini)
- Validate real database operations
- Test RLS policies, constraints, triggers
- Slower (~50-200ms per test) but trustworthy
- **This is your primary testing strategy**

**Unit Tests** (10% of tests)
- Test pure utility functions that don't touch database
- Example: `extractMatchPattern()`, `calculateMonthlyAmount()`
- Example: Data transformation helpers
- Fast (<1ms per test)

**E2E Tests** (future)
- Full request-to-response flow
- Use real local services + Plaid sandbox
- Run separately from main test suite

---

## 📋 REVISED IMPLEMENTATION PLAN

### Decision: Remove and Rebuild

**Why remove rather than refactor?**

1. **Fundamental architecture is wrong** - 638 lines of mock infrastructure solving the wrong problem
2. **3,500 lines based on flawed approach** - rewriting will be faster and better
3. **False confidence** - current tests pass but don't validate real behavior
4. **Simpler path forward** - real Supabase testing is actually simpler than mocks
5. **Supabase recommends it** - we should follow official guidance

**What to salvage:**
- ✅ Test infrastructure (deno.jsonc, tasks) - keep as-is
- ✅ Environment setup pattern - keep
- ✅ Test file structure - keep the files, rewrite contents
- ✅ JWT utilities (`createTestJWT`) - keep, it's useful
- ⚠️ Test cases - keep the test descriptions/scenarios, rewrite implementations
- ❌ All mock utilities - delete completely
- ❌ IS_LOCAL_DEV code - delete completely

---

### Phase 1: Cleanup & Foundation (Week 1)

#### Step 1A: Remove Mock Infrastructure ⚠️ NEW
**Time estimate:** 1-2 hours

**EXACT STEPS TO FOLLOW:**

**1. Get local Supabase credentials**

```bash
# Start local Supabase (if not already running)
cd /Users/anton/ws/mymoney
supabase start

# Output will show credentials - COPY THESE:
# - API URL: http://localhost:54321
# - anon key: eyJh...
# - service_role key: eyJh...
# - JWT secret: super-secret-jwt-token-with-at-least-32-characters-long
```

**2. Create `.env.local` file**

```bash
# Create file at exact location
cat > /Users/anton/ws/mymoney/supabase/functions/.env.local << 'EOF'
# Local Supabase credentials (from `supabase start` output)
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=<PASTE_ANON_KEY_HERE>
SUPABASE_SERVICE_ROLE_KEY=<PASTE_SERVICE_ROLE_KEY_HERE>
SUPABASE_JWT_SECRET=<PASTE_JWT_SECRET_HERE>

# Custom env vars (same values as above, workaround for reserved names)
CUSTOM_SUPABASE_URL=http://localhost:54321
CUSTOM_ANON_KEY=<PASTE_ANON_KEY_HERE>
CUSTOM_SERVICE_ROLE_KEY=<PASTE_SERVICE_ROLE_KEY_HERE>

# Plaid Sandbox credentials (REAL Plaid sandbox, not mocked)
# ⚠️ DO NOT COMMIT THIS FILE TO GIT - Add to .gitignore
PLAID_CLIENT_ID=5cfea7d083a3230012cc3b9d
PLAID_SECRET=b9376414937a1160da8e954f6307c8
PLAID_ENV=sandbox
PLAID_WEBHOOK_VERIFICATION_KEY=<get_from_dashboard_if_testing_webhooks>

# Webhook URL (local)
PLAID_WEBHOOK_URL=http://localhost:54321/functions/v1/plaid-webhook
EOF
```

**3. Clean production code pollution**

File: `/Users/anton/ws/mymoney/supabase/functions/plaid-link-token/index.ts`

DELETE these exact lines (56-84):
```typescript
    const isLocal = Deno.env.get('IS_LOCAL_DEV') === 'true';
    let user;
    let supabase;

    if (isLocal) {
      console.log('⚠️  Running locally - Auth bypassed for testing');
      user = { id: 'local-test-user-123' };
    } else {
      try {
        supabase = config.createSupabaseClient(req);
        const authResult = await requireAuth(req, supabase);
        if (authResult instanceof Response) {
          return authResult;
        }
        user = authResult;
        if (!user) {
          return jsonResponse(
            { error: 'Unauthorized', message: 'User not found after auth' },
            401
          );
        }
      } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        return jsonResponse(
          { error: 'Authentication error', message },
          401
        );
      }
    }
```

REPLACE with this simpler code:
```typescript
    // Get authenticated user
    let user;
    let supabase;

    try {
      supabase = config.createSupabaseClient(req);
      const authResult = await requireAuth(req, supabase);
      if (authResult instanceof Response) {
        return authResult;
      }
      user = authResult;
      if (!user) {
        return jsonResponse(
          { error: 'Unauthorized', message: 'User not found after auth' },
          401
        );
      }
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      return jsonResponse(
        { error: 'Authentication error', message },
        401
      );
    }
```

**4. Clean test file references to IS_LOCAL_DEV**

File: `/Users/anton/ws/mymoney/supabase/functions/plaid-link-token/index.test.ts`

DELETE these test cases entirely:
- `plaid-link-token: local dev mode bypasses auth` (lines 114-135)
- `plaid-link-token: local dev with item id falls back to new link mode` (lines 167-201)

These tests are testing the bypass mechanism we just removed.

**VALIDATION CHECKLIST:**

Run these checks:
```bash
cd /Users/anton/ws/mymoney/supabase/functions

# 1. Check .env.local exists
test -f .env.local && echo "✅ .env.local exists" || echo "❌ .env.local missing"

# 2. Check no IS_LOCAL_DEV in production code
grep -r "IS_LOCAL_DEV" --include="*.ts" --exclude="*.test.ts" . && echo "❌ Found IS_LOCAL_DEV" || echo "✅ No IS_LOCAL_DEV"

# 3. Check Supabase is running
supabase status | grep "API URL" || echo "❌ Supabase not running"

# 4. Verify test-utils.ts will be small (check current size)
wc -l _shared/test-utils.ts
# Should be 638 lines now, will be ~100 after next step
```

**Expected results:**
- ✅ `.env.local` file exists
- ✅ No `IS_LOCAL_DEV` in production code
- ✅ Supabase running on `http://localhost:54321`
- ⚠️ `test-utils.ts` still large (will fix in Step 1B)

#### Step 1B: Create Real Test Utilities ✅ NEW
**Time estimate:** 2-3 hours

**EXACT STEPS TO FOLLOW:**

**1. Replace entire test-utils.ts file**

File: `/Users/anton/ws/mymoney/supabase/functions/_shared/test-utils.ts`

**ACTION: Delete current contents (638 lines) and replace with this EXACT content:**

```typescript
/**
 * Shared test utilities for Edge Functions
 *
 * IMPORTANT: Tests run against LOCAL Supabase instance, not mocks.
 * Start local Supabase with: supabase start
 */

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { load } from "https://deno.land/std@0.224.0/dotenv/mod.ts";

// Load test environment variables
let envLoaded = false;

/**
 * Loads test environment variables from .env.local file
 * Call this at the beginning of EVERY test file
 *
 * @example
 * ```typescript
 * import { setupTestEnvironment } from '../_shared/test-utils.ts';
 * await setupTestEnvironment();
 * ```
 */
export async function setupTestEnvironment() {
  if (!envLoaded) {
    try {
      await load({
        envPath: new URL("../.env.local", import.meta.url).pathname,
        export: true,
      });
      envLoaded = true;
    } catch (error) {
      console.warn("Warning: Could not load .env.local file:", (error as Error).message);
      console.warn("Tests will use system environment variables");
    }
  }
}

/**
 * Creates a REAL Supabase client pointing to local instance
 * Use this for authenticated user operations
 *
 * @returns Real SupabaseClient (NOT A MOCK)
 */
export function createTestSupabaseClient(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL') || Deno.env.get('CUSTOM_SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_ANON_KEY') || Deno.env.get('CUSTOM_ANON_KEY');

  if (!url || !key) {
    throw new Error('SUPABASE_URL and SUPABASE_ANON_KEY must be set. Run setupTestEnvironment() first.');
  }

  return createClient(url, key);
}

/**
 * Creates a REAL Supabase client with service role (bypasses RLS)
 * Use this for test setup/teardown that needs to bypass RLS
 *
 * @returns Real SupabaseClient with service role (NOT A MOCK)
 */
export function createTestServiceRoleClient(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL') || Deno.env.get('CUSTOM_SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('CUSTOM_SERVICE_ROLE_KEY');

  if (!url || !key) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY must be set. Run setupTestEnvironment() first.');
  }

  return createClient(url, key);
}

/**
 * Generates a REAL JWT token for testing authenticated requests
 * This creates a valid JWT that will be accepted by local Supabase
 *
 * @param options - JWT configuration
 * @returns Bearer token string (e.g., "Bearer eyJh...")
 */
export async function createTestJWT(options: {
  userId?: string;
  role?: string;
  expiresIn?: number;
} = {}): Promise<string> {
  const {
    userId = 'test-user-id',
    role = 'authenticated',
    expiresIn = 3600,
  } = options;

  const { create } = await import("https://deno.land/x/djwt@v2.8/mod.ts");

  const secret = Deno.env.get('SUPABASE_JWT_SECRET');
  if (!secret) {
    throw new Error('SUPABASE_JWT_SECRET must be set. Run setupTestEnvironment() first.');
  }

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const now = Math.floor(Date.now() / 1000);

  const jwt = await create(
    { alg: "HS256", typ: "JWT" },
    {
      sub: userId,
      role: role,
      aud: "authenticated",
      exp: now + expiresIn,
      iat: now,
    },
    key
  );

  return `Bearer ${jwt}`;
}

/**
 * Helper to manage test data lifecycle: setup → test → cleanup
 * Ensures cleanup runs even if test fails
 *
 * @example
 * ```typescript
 * await withTestData(
 *   // Setup: create test data
 *   async () => {
 *     const supabase = createTestServiceRoleClient();
 *     const { data } = await supabase.from('items').insert({...}).select().single();
 *     return data;
 *   },
 *   // Cleanup: delete test data
 *   async (data) => {
 *     const supabase = createTestServiceRoleClient();
 *     await supabase.from('items').delete().eq('id', data.id);
 *   },
 *   // Test: verify behavior
 *   async (data) => {
 *     assertEquals(data.field, expectedValue);
 *   }
 * );
 * ```
 */
export async function withTestData<T>(
  setup: () => Promise<T>,
  cleanup: (data: T) => Promise<void>,
  test: (data: T) => Promise<void>
): Promise<void> {
  const data = await setup();
  try {
    await test(data);
  } finally {
    try {
      await cleanup(data);
    } catch (cleanupError) {
      console.error('Cleanup error:', cleanupError);
      // Don't throw - we want test failure, not cleanup failure
    }
  }
}

/**
 * Creates a REAL Plaid client configured for sandbox testing
 *
 * ⚠️ IMPORTANT: This uses REAL Plaid sandbox (sandbox.plaid.com), NOT mocks
 *
 * Plaid provides a free sandbox environment with:
 * - Rich test data
 * - Deterministic behavior
 * - Test institutions (use "ins_109508" for First Platypus Bank)
 * - Default credentials: user_good / pass_good
 *
 * Patterns inspired by Plaid AI Coding Toolkit:
 * https://github.com/plaid/ai-coding-toolkit/tree/main/sandbox
 *
 * Official docs: https://plaid.com/docs/sandbox/
 *
 * @returns Real PlaidApi instance pointed at sandbox
 */
export async function createTestPlaidClient() {
  const { PlaidApi, PlaidEnvironments, Configuration } = await import('npm:plaid@31.1.0');

  const clientId = Deno.env.get('PLAID_CLIENT_ID');
  const secret = Deno.env.get('PLAID_SECRET');

  if (!clientId || !secret) {
    throw new Error('PLAID_CLIENT_ID and PLAID_SECRET must be set in .env.local');
  }

  const configuration = new Configuration({
    basePath: PlaidEnvironments.sandbox,
    baseOptions: {
      headers: {
        'PLAID-CLIENT-ID': clientId,
        'PLAID-SECRET': secret,
      },
    },
  });

  return new PlaidApi(configuration);
}

/**
 * Creates a test Item in Plaid sandbox without going through Link flow
 *
 * This bypasses the UI flow and directly creates an Item with mocked data.
 * Uses Plaid's /sandbox/public_token/create endpoint.
 *
 * Pattern from Plaid AI Coding Toolkit - provides working access token + item ID.
 *
 * @param options - Test item configuration
 * @returns Object with public_token, item_id, and access_token (after exchange)
 *
 * @example
 * ```typescript
 * // Create item and exchange for access token (all sandbox)
 * const { access_token, item_id } = await createTestPlaidItem();
 *
 * // Now use access_token for testing transactions, accounts, etc.
 * const { data } = await plaid.accountsGet({ access_token });
 * ```
 */
export async function createTestPlaidItem(options: {
  institutionId?: string;
  initialProducts?: string[];
  testCredentials?: 'good' | 'bad' | 'locked';
} = {}) {
  const plaid = await createTestPlaidClient();

  const {
    institutionId = 'ins_109508', // First Platypus Bank (test institution)
    initialProducts = ['transactions'],
    testCredentials = 'good', // user_good / user_bad / user_locked
  } = options;

  // Create public token in sandbox
  const createResponse = await plaid.sandboxPublicTokenCreate({
    institution_id: institutionId,
    initial_products: initialProducts,
    options: {
      override_username: `user_${testCredentials}`,
      override_password: `pass_${testCredentials}`,
    },
  });

  const public_token = createResponse.data.public_token;

  // Exchange for access token
  const exchangeResponse = await plaid.itemPublicTokenExchange({
    public_token: public_token,
  });

  return {
    public_token: public_token,
    access_token: exchangeResponse.data.access_token,
    item_id: exchangeResponse.data.item_id,
    institution_id: institutionId,
  };
}

/**
 * Generates mock transaction data in Plaid sandbox
 *
 * Uses /sandbox/item/fire_webhook to trigger transaction updates.
 * Pattern from Plaid AI Coding Toolkit.
 *
 * @param accessToken - Plaid access token
 * @param webhookCode - Type of webhook to fire
 */
export async function triggerPlaidSandboxWebhook(
  accessToken: string,
  webhookCode: 'DEFAULT_UPDATE' | 'TRANSACTIONS_REMOVED' | 'HISTORICAL_UPDATE' = 'DEFAULT_UPDATE'
) {
  const plaid = await createTestPlaidClient();

  await plaid.sandboxItemFireWebhook({
    access_token: accessToken,
    webhook_code: webhookCode,
  });
}

/**
 * Resets Plaid sandbox item login (useful for testing error states)
 *
 * @param accessToken - Plaid access token
 */
export async function resetPlaidSandboxItem(accessToken: string) {
  const plaid = await createTestPlaidClient();

  await plaid.sandboxItemResetLogin({
    access_token: accessToken,
  });
}

// Re-export standard assertions for convenience
export {
  assertEquals,
  assertExists,
  assertRejects,
  assertStrictEquals,
  assertThrows,
  assertNotEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

// Re-export FakeTime for testing time-dependent code
export { FakeTime } from "https://deno.land/std@0.224.0/testing/time.ts";
```

**2. Verify the changes**

```bash
cd /Users/anton/ws/mymoney/supabase/functions

# Count lines - should be ~350 lines (down from 638)
wc -l _shared/test-utils.ts

# Verify no MockQueryBuilder exists
grep -n "MockQueryBuilder" _shared/test-utils.ts && echo "❌ Still has MockQueryBuilder" || echo "✅ MockQueryBuilder removed"

# Verify no createMockSupabaseClient exists
grep -n "createMockSupabaseClient" _shared/test-utils.ts && echo "❌ Still has mock Supabase" || echo "✅ Mock Supabase removed"

# Verify real Plaid client exists (not mocked)
grep -n "createTestPlaidClient" _shared/test-utils.ts && echo "✅ Has real Plaid sandbox client" || echo "❌ Missing Plaid client"
```

**3. Test Plaid credentials**

```bash
# Quick test that Plaid credentials work
cd /Users/anton/ws/mymoney/supabase/functions

# Create a test script to verify Plaid connection
cat > /tmp/test-plaid.ts << 'EOF'
import { setupTestEnvironment, createTestPlaidClient, createTestPlaidItem } from './_shared/test-utils.ts';

await setupTestEnvironment();

console.log('Testing Plaid sandbox connection...');

// Test 1: Create Plaid client
const plaid = await createTestPlaidClient();
console.log('✅ Plaid client created');

// Test 2: Create test item
const { access_token, item_id } = await createTestPlaidItem();
console.log(`✅ Test item created: ${item_id}`);

// Test 3: Get accounts
const { data } = await plaid.accountsGet({ access_token });
console.log(`✅ Retrieved ${data.accounts.length} accounts`);

console.log('\n🎉 Plaid sandbox is working!');
EOF

# Run the test
deno run --allow-all /tmp/test-plaid.ts
```

**Expected output:**
```
Testing Plaid sandbox connection...
✅ Plaid client created
✅ Test item created: item_XXXXX
✅ Retrieved 3 accounts

🎉 Plaid sandbox is working!
```

**VALIDATION CHECKLIST:**

- [ ] test-utils.ts is ~350 lines (down from 638)
- [ ] No `MockQueryBuilder` class exists
- [ ] No `createMockSupabaseClient` function exists
- [ ] `createTestSupabaseClient()` returns REAL Supabase client
- [ ] `createTestServiceRoleClient()` returns REAL Supabase client
- [ ] `createTestPlaidClient()` returns REAL Plaid client (not mocked)
- [ ] `createTestPlaidItem()` creates real sandbox items
- [ ] `triggerPlaidSandboxWebhook()` simulates real webhooks
- [ ] All functions have clear documentation
- [ ] Comments explicitly say "REAL" or "NOT A MOCK"
- [ ] Plaid sandbox connection test passes

**Expected output:**
```
✅ test-utils.ts reduced from 638 → ~350 lines
✅ MockQueryBuilder removed
✅ Mock Supabase removed
✅ Real Plaid sandbox client added
✅ Plaid credentials verified working
```

---

### Phase 2: Rewrite Tests Against Real Database (Weeks 2-4)

#### Step 2: Rewrite Shared Module Tests
**Time estimate:** 8-12 hours

For each shared module (`auth.ts`, `plaid.ts`, `recurring.ts`):

**Example: auth.test.ts (REWRITTEN)**

```typescript
import { assertEquals, assertExists } from '../_shared/test-utils.ts';
import {
  createAuthenticatedClient,
  getAuthenticatedUser,
  requireAuth,
} from './auth.ts';
import {
  setupTestEnvironment,
  createTestJWT,
  createTestSupabaseClient,
  withTestData,
} from './test-utils.ts';

await setupTestEnvironment();

Deno.test('createAuthenticatedClient: creates client with auth header', async () => {
  const jwt = await createTestJWT({ userId: 'test-user-123' });

  const req = new Request('http://localhost', {
    headers: { Authorization: jwt }
  });

  // Call real function
  const supabase = createAuthenticatedClient(req);

  // Verify against REAL database
  const { data: { user }, error } = await supabase.auth.getUser();

  // This validates:
  // - JWT is correctly formatted
  // - Supabase validates the JWT
  // - User extraction works
  assertExists(user);
  assertEquals(user.id, 'test-user-123');
});

Deno.test('requireAuth: enforces RLS on database queries', async () => {
  await withTestData(
    // Setup: Insert test data for two users
    async () => {
      const supabase = createTestServiceRoleClient();

      const { data: item1 } = await supabase
        .from('items_table')
        .insert({ user_id: 'user-1', bank_name: 'Bank A' })
        .select()
        .single();

      const { data: item2 } = await supabase
        .from('items_table')
        .insert({ user_id: 'user-2', bank_name: 'Bank B' })
        .select()
        .single();

      return { item1, item2 };
    },
    // Cleanup: Remove test data
    async ({ item1, item2 }) => {
      const supabase = createTestServiceRoleClient();
      await supabase.from('items_table').delete().in('id', [item1.id, item2.id]);
    },
    // Test: Verify RLS works
    async ({ item1, item2 }) => {
      const jwt = await createTestJWT({ userId: 'user-1' });
      const req = new Request('http://localhost', {
        headers: { Authorization: jwt }
      });

      const supabase = createAuthenticatedClient(req);

      // Query should only return user-1's items due to RLS
      const { data: items } = await supabase
        .from('items_table')
        .select('*');

      assertEquals(items.length, 1);
      assertEquals(items[0].id, item1.id);
      // Cannot see user-2's item due to RLS - this is what we're testing!
    }
  );
});

Deno.test('requireAuth: returns 401 for invalid JWT', async () => {
  const req = new Request('http://localhost', {
    headers: { Authorization: 'Bearer invalid-jwt-token' }
  });

  const result = await requireAuth(req);

  // Validates real JWT checking
  assertEquals(result instanceof Response, true);
  assertEquals((result as Response).status, 401);
});
```

**What this tests that mocks don't:**
- ✅ Real JWT validation by Supabase
- ✅ RLS policies actually work
- ✅ Database connection works
- ✅ User isolation is enforced
- ✅ SQL queries are syntactically correct
- ✅ Tables/columns exist
- ✅ Auth flow integrates correctly

#### Step 3: Rewrite Function Tests
**Time estimate:** 12-16 hours

**Example: create-manual-stream/index.test.ts (REWRITTEN)**

```typescript
import { assertEquals, assertExists } from '../_shared/test-utils.ts';
import {
  setupTestEnvironment,
  createTestJWT,
  createTestServiceRoleClient,
  withTestData,
} from '../_shared/test-utils.ts';

await setupTestEnvironment();

Deno.test('create-manual-stream: creates stream with real database', async () => {
  await withTestData(
    // Setup real test data in real database
    async () => {
      const supabase = createTestServiceRoleClient();

      // Insert real item
      const { data: item } = await supabase
        .from('items_table')
        .insert({
          user_id: 'test-user-123',
          plaid_item_id: 'item_test',
          bank_name: 'Test Bank',
          plaid_access_token: 'access_test'
        })
        .select()
        .single();

      // Insert real account
      const { data: account } = await supabase
        .from('accounts_table')
        .insert({
          user_id: 'test-user-123',
          item_id: item.id,
          plaid_account_id: 'acc_test',
          name: 'Checking',
          type: 'depository'
        })
        .select()
        .single();

      // Insert real transaction
      const { data: transaction } = await supabase
        .from('transactions_table')
        .insert({
          user_id: 'test-user-123',
          account_id: account.id,
          plaid_transaction_id: 'tx_test',
          name: 'Netflix Subscription',
          merchant_name: 'Netflix',
          amount: 15.99,
          date: '2026-01-15',
          personal_finance_category: 'ENTERTAINMENT'
        })
        .select()
        .single();

      return { item, account, transaction };
    },
    // Cleanup
    async ({ item, account, transaction }) => {
      const supabase = createTestServiceRoleClient();

      // Delete in correct order (foreign keys)
      const { data: streams } = await supabase
        .from('recurring_streams_table')
        .select('id')
        .eq('user_id', 'test-user-123');

      if (streams?.length) {
        await supabase
          .from('recurring_stream_transactions_table')
          .delete()
          .in('stream_id', streams.map(s => s.id));

        await supabase
          .from('recurring_streams_table')
          .delete()
          .in('id', streams.map(s => s.id));
      }

      await supabase.from('transactions_table').delete().eq('id', transaction.id);
      await supabase.from('accounts_table').delete().eq('id', account.id);
      await supabase.from('items_table').delete().eq('id', item.id);
    },
    // Test
    async ({ transaction }) => {
      const jwt = await createTestJWT({ userId: 'test-user-123' });

      // Call REAL function endpoint
      const req = new Request('http://localhost/create-manual-stream', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: jwt,
        },
        body: JSON.stringify({
          transaction_id: transaction.id,
          frequency: 'monthly',
        }),
      });

      // Import and call real handler
      const { default: handler } = await import('./index.ts');
      const res = await handler(req);

      assertEquals(res.status, 200);

      const body = await res.json();
      assertExists(body.stream);
      assertEquals(body.stream.description, 'Netflix');

      // Verify in REAL database
      const supabase = createTestServiceRoleClient();
      const { data: stream } = await supabase
        .from('recurring_streams_table')
        .select('*')
        .eq('id', body.stream.id)
        .single();

      assertExists(stream);
      assertEquals(stream.match_pattern, 'NETFLIX');
      assertEquals(stream.is_manual, true);
      assertEquals(stream.frequency, 'MONTHLY');

      // Verify profile was updated (tests the full flow)
      const { data: profile } = await supabase
        .from('profiles_table')
        .select('monthly_mandatory_expenses')
        .eq('id', 'test-user-123')
        .single();

      assertExists(profile);
      // This validates the entire chain: function → DB → triggers → profile update
    }
  );
});
```

**What this approach validates:**
- ✅ Real SQL queries work
- ✅ Foreign key relationships work
- ✅ Database constraints are enforced
- ✅ RLS policies work correctly
- ✅ Database triggers fire correctly
- ✅ Profile updates happen as expected
- ✅ The full integration works end-to-end

---

### Phase 3: External API Testing Strategy (Week 4)

#### Use Real Plaid Sandbox ✅

Plaid provides a free sandbox environment - use it instead of mocks:

```typescript
// plaid.test.ts - Use REAL Plaid sandbox

import { createTestPlaidClient, createTestPlaidItem } from '../_shared/test-utils.ts';

Deno.test('save-item: exchanges public token with Plaid', async () => {
  await withTestData(
    // Setup: Create test item in REAL Plaid sandbox
    async () => {
      // This makes REAL API calls to sandbox.plaid.com
      // Pattern from Plaid AI Coding Toolkit
      const { access_token, item_id } = await createTestPlaidItem({
        institutionId: 'ins_109508', // First Platypus Bank
        initialProducts: ['transactions'],
        testCredentials: 'good', // user_good / pass_good
      });

      return { access_token, item_id };
    },

    // Cleanup: Remove from database
    async ({ item_id }) => {
      const supabase = createTestServiceRoleClient();
      await supabase.from('items_table').delete().eq('plaid_item_id', item_id);
    },

    // Test: Verify save-item function
    async ({ access_token, item_id }) => {
      // Test with real Plaid sandbox credentials
      const plaid = await createTestPlaidClient();

      // Get real accounts from sandbox
      const { data } = await plaid.accountsGet({ access_token });
      assertEquals(data.accounts.length > 0, true);

      // Save to REAL database
      const supabase = createTestServiceRoleClient();
      const { data: savedItem } = await supabase
        .from('items_table')
        .insert({
          plaid_access_token: access_token,
          plaid_item_id: item_id,
          bank_name: 'First Platypus Bank',
        })
        .select()
        .single();

      assertExists(savedItem);
      assertEquals(savedItem.plaid_item_id, item_id);

      // Verify accounts were saved
      const { data: savedAccounts } = await supabase
        .from('accounts_table')
        .select('*')
        .eq('item_id', savedItem.id);

      assertEquals(savedAccounts.length, data.accounts.length);
    }
  );
});
```

**Use real sandbox environments:**
- Plaid → sandbox.plaid.com ✅
- Stripe → test mode ✅
- Most payment/banking APIs → have free sandboxes ✅

**Mock only when necessary:**
- Gemini API (costs money) ✅
- APIs without free sandbox ✅
- Network-isolated CI (last resort) ✅

**Never mock your own services:**
- Supabase ❌
- Your utility functions ❌
- Your business logic ❌
- APIs that have free sandboxes ❌

---

## 📊 COMPARISON: Before vs After

### Before (Current Implementation)

```typescript
// ❌ WRONG - Testing mock behavior
const mockSupabase = createMockSupabaseClient({
  mockData: {
    transactions_table: [{ id: 1, name: 'Test', amount: 50 }]
  }
});

const { data } = await mockSupabase
  .from('transactions_table')
  .select('*')
  .eq('user_id', 'test-user');

assertEquals(data.length, 1); // Tests mock implementation!
```

**What this validates:**
- ✅ Mock's .eq() method works
- ❌ Real query syntax
- ❌ Database table exists
- ❌ RLS policies
- ❌ Constraints

### After (Correct Implementation)

```typescript
// ✅ CORRECT - Testing real behavior
const supabase = createTestSupabaseClient();

// Insert real data
await supabase
  .from('transactions_table')
  .insert({
    user_id: 'test-user',
    name: 'Test Transaction',
    amount: 50,
    // ... all required fields
  });

// Query real database
const { data, error } = await supabase
  .from('transactions_table')
  .select('*')
  .eq('user_id', 'test-user');

assertExists(data);
assertEquals(data.length, 1); // Tests real database behavior!
```

**What this validates:**
- ✅ Real query syntax is correct
- ✅ Database table exists
- ✅ RLS policies work
- ✅ All constraints satisfied
- ✅ Actual behavior matches expectations

---

## 🎯 REVISED SUCCESS CRITERIA

### Technical
- ✅ Tests run against local Supabase (`supabase start`)
- ✅ No mock database infrastructure
- ✅ No IS_LOCAL_DEV in production code
- ✅ Only external APIs mocked (Plaid, Gemini)
- ✅ Test utilities < 150 lines
- ✅ Tests validate real database behavior
- ✅ RLS policies tested with real JWT
- ✅ Foreign keys and constraints tested

### Coverage (Maintained)
- ✅ 80%+ code coverage across functions
- ✅ Test suite runs in < 30 seconds locally
- ✅ CI/CD integration working

### Quality
- ✅ Tests catch real bugs (not mock bugs)
- ✅ Confidence in refactoring
- ✅ Production parity (tests == prod behavior)
- ✅ No false positives from mock discrepancies

---

## 📅 REVISED TIMELINE

| Week | Phase | Focus | Hours |
|------|-------|-------|-------|
| 1 | Cleanup | Remove mocks, create real utilities | 4-6 |
| 2 | Shared | Rewrite auth/plaid/recurring tests | 8-12 |
| 3 | Functions | Rewrite simple function tests | 10-14 |
| 4 | Integration | Complex functions + cleanup | 12-16 |
| **Total** | | | **34-48 hours** |

**Faster than original because:**
- No complex mock logic to maintain
- Real Supabase is simpler than mocks
- Leverage existing test case structure
- Clear patterns from rewritten examples

---

## 🚀 IMMEDIATE NEXT STEPS

1. **Read this plan completely** ✋
2. **Ensure local Supabase works**: `supabase start`
3. **Decision point**: Confirm deletion of mock infrastructure
4. **Execute Step 1A**: Remove mocks, clean production code (1-2 hours)
5. **Execute Step 1B**: Create real test utilities (2-3 hours)
6. **Rewrite one test file** as proof of concept (auth.test.ts recommended)
7. **Validate approach** - does it catch real bugs?
8. **Continue with remaining tests**

---

## ⚠️ KEY PRINCIPLES TO REMEMBER

### 1. MOCKS ARE A LAST RESORT
Only mock when:
- External service you don't control (Plaid, Gemini)
- Costs money or has rate limits
- Can't run locally

Never mock when:
- You control the service (Supabase)
- Can run locally for free (local Supabase)
- Need to test integration behavior

### 2. TRUST REAL BEHAVIOR
- A passing test against mocks means mocks work
- A passing test against real DB means your code works
- Choose the latter

### 3. PRODUCTION PARITY
- Tests should mirror production as closely as possible
- Local Supabase = production Supabase (same DB engine, RLS, etc.)
- Mocks ≠ production (different behavior, false confidence)

---

## 📚 RESOURCES

### Official Guidance
- [Supabase: Testing Edge Functions](https://supabase.com/docs/guides/functions/unit-test) - **Read this first**
- [Deno: Testing](https://docs.deno.com/examples/testing_tutorial/)

### Local Supabase
- [Supabase CLI Reference](https://supabase.com/docs/reference/cli/supabase-start)
- [Local Development](https://supabase.com/docs/guides/cli/local-development)

### Why Mocking Can Be Harmful
- [TestDouble: Why We Don't Mock](https://blog.testdouble.com/posts/2018-03-06-please-dont-mock-me/)
- [Kent C. Dodds: Write tests. Not too many. Mostly integration.](https://kentcdodds.com/blog/write-tests)

---

## CROSS-REFERENCE: Original Plan Status vs Reality

| Step | Original Status | Reality Check | Action Required |
|------|----------------|---------------|-----------------|
| Step 1 | ✅ Complete | ✅ Good - keep | None |
| Step 2 | ✅ Complete | ❌ Flawed approach | DELETE mock infrastructure |
| Step 3 | ✅ Complete | ✅ Good - keep | Update to use .env.local |
| Step 4 | ✅ Complete | ❌ Tests mock behavior | REWRITE against real DB |
| Step 5 | ✅ Complete | ❌ Tests mock behavior | REWRITE against real DB |
| Step 6 | ✅ Complete | ❌ Tests mock behavior | REWRITE against real DB |
| Step 7 | ⚠️ Partial | ❌ Tests mock behavior | REWRITE against real DB |
| Steps 8-10 | ❌ Not started | - | Follow new approach |

**Total lines to remove:** ~3,100 (638 mock utils + 2,459 flawed tests)
**Total lines to write:** ~1,500 (100 real utils + 1,400 real tests)
**Net reduction:** ~1,600 lines while improving quality

---

**The bottom line:** We spent significant effort building infrastructure to test mocks instead of code. The right path forward is to remove the mock infrastructure, clean up production code pollution, and rebuild tests the way Supabase recommends: against a real local instance. This will give us actual confidence our code works.

---

## 📋 LLM AGENT QUICK REFERENCE

### Current State
```
✅ Infrastructure exists (deno.jsonc, tasks)
❌ 638 lines of mock DB utilities (test-utils.ts)
❌ 3,500 lines of tests testing mocks
❌ IS_LOCAL_DEV pollution in production code
```

### Target State
```
✅ Infrastructure (keep as-is)
✅ ~250 lines of real utilities (test-utils.ts)
✅ ~1,500 lines of tests testing real DB
✅ Clean production code (no test bypasses)
```

### Action Checklist (Execute in Order)

**Phase 1: Cleanup (Do First)**
- [ ] 1.A.1: Run `supabase start`, note credentials
- [ ] 1.A.2: Create `.env.local` with local Supabase credentials
- [ ] 1.A.3: Edit `plaid-link-token/index.ts` - remove IS_LOCAL_DEV logic (lines 56-84)
- [ ] 1.A.4: Edit `plaid-link-token/index.test.ts` - delete 2 IS_LOCAL_DEV test cases
- [ ] 1.A.5: Validate: no IS_LOCAL_DEV in production code
- [ ] 1.B.1: Replace `_shared/test-utils.ts` with new version (638→250 lines)
- [ ] 1.B.2: Validate: no MockQueryBuilder, no createMockSupabaseClient
- [ ] 1.B.3: Add `.env.local` to `.gitignore` if not already there
- [ ] 1.B.4: Verify Plaid credentials work (see validation commands below)

**Add to .gitignore:**
```bash
# Add this line to /Users/anton/ws/mymoney/.gitignore if not present
echo "supabase/functions/.env.local" >> .gitignore
```

**Phase 2: Rewrite Tests (One at a Time)**

For EACH test file below, follow this pattern:
1. Read current test file
2. Keep test case names/descriptions
3. Rewrite implementation using real DB
4. Use `withTestData()` for setup/cleanup
5. Verify with `deno test <file>`

Test files to rewrite:
- [ ] `_shared/auth.test.ts` (426 lines → ~300 lines)
- [ ] `_shared/plaid.test.ts` (587 lines → ~200 lines)
- [ ] `_shared/recurring.test.ts` (1,145 lines → ~400 lines)
- [ ] `create-manual-stream/index.test.ts` (107 lines → ~150 lines)
- [ ] `plaid-link-token/index.test.ts` (201 lines → ~150 lines)
- [ ] `update-webhooks/index.test.ts` (101 lines → ~100 lines)

**Validation After Each File:**
```bash
# Run the test
deno test <file>

# Verify it uses real DB (should see these)
grep "createTestSupabaseClient" <file>
grep "createTestServiceRoleClient" <file>
grep "withTestData" <file>

# Verify it doesn't use mocks (should NOT see these)
grep "createMockSupabaseClient" <file> && echo "❌ Still using mock" || echo "✅ Clean"
grep "mockData" <file> && echo "❌ Still using mock" || echo "✅ Clean"
```

### Test Rewriting Pattern (Copy This)

```typescript
// ALWAYS at top of test file
import { setupTestEnvironment, createTestServiceRoleClient, withTestData } from '../_shared/test-utils.ts';
await setupTestEnvironment();

// PATTERN for each test
Deno.test('descriptive name', async () => {
  await withTestData(
    // SETUP: Insert real data
    async () => {
      const supabase = createTestServiceRoleClient();
      const { data } = await supabase.from('table').insert({...}).select().single();
      return data;
    },

    // CLEANUP: Delete real data
    async (data) => {
      const supabase = createTestServiceRoleClient();
      await supabase.from('table').delete().eq('id', data.id);
    },

    // TEST: Verify behavior
    async (data) => {
      // Call your function
      const result = await yourFunction(data);

      // Verify in real database
      const supabase = createTestServiceRoleClient();
      const { data: verified } = await supabase.from('table').select('*').eq('id', result.id).single();

      assertEquals(verified.field, expected);
    }
  );
});
```

### Common Patterns

**Testing Auth:**
```typescript
const jwt = await createTestJWT({ userId: 'test-user' });
const req = new Request('http://localhost', { headers: { Authorization: jwt } });
const supabase = createAuthenticatedClient(req);
// Now test with real supabase
```

**Testing RLS:**
```typescript
// Insert data for two users
const { data: item1 } = await supabase.from('items').insert({ user_id: 'user-1', ... }).select().single();
const { data: item2 } = await supabase.from('items').insert({ user_id: 'user-2', ... }).select().single();

// Query as user-1 (with JWT)
const jwt = await createTestJWT({ userId: 'user-1' });
const userSupabase = createAuthenticatedClient(req);
const { data: items } = await userSupabase.from('items').select('*');

// Verify only sees their own data
assertEquals(items.length, 1);
assertEquals(items[0].id, item1.id);
```

**Testing Foreign Keys:**
```typescript
// Setup: Create parent → child
const { data: parent } = await supabase.from('items').insert({...}).select().single();
const { data: child } = await supabase.from('accounts').insert({ item_id: parent.id, ... }).select().single();

// Test: Try to delete parent (should fail due to FK)
const { error } = await supabase.from('items').delete().eq('id', parent.id);
assertExists(error); // FK constraint violated

// Cleanup: Delete child first, then parent
await supabase.from('accounts').delete().eq('id', child.id);
await supabase.from('items').delete().eq('id', parent.id);
```

### Red Flags (Stop If You See These)

```typescript
// ❌ BAD - Mocking Supabase
const mockSupabase = createMockSupabaseClient({ mockData: {...} });

// ❌ BAD - Mocking Plaid (it has a free sandbox!)
const mockPlaid = createMockPlaidClient({ ... });

// ❌ BAD - Mocking your own functions
const mockAuth = { getUser: () => ({ user: { id: 'test' } }) };

// ❌ BAD - Test mode in production code
if (Deno.env.get('IS_TEST') === 'true') { /* bypass logic */ }

// ✅ GOOD - Real Supabase
const supabase = createTestServiceRoleClient();

// ✅ GOOD - Real JWT
const jwt = await createTestJWT({ userId: 'test-user' });

// ✅ GOOD - Real Plaid sandbox
const plaid = await createTestPlaidClient();
const { public_token } = await createTestPlaidItem();

// ⚠️ ACCEPTABLE - Mocking API without free sandbox (document why)
const mockGemini = { generateContent: () => ({ text: 'test' }) };
```

### Quick Diagnosis

**If tests fail with "table not found":**
- ✅ Local Supabase running? (`supabase status`)
- ✅ Database migrations applied? (`supabase db reset`)
- ✅ Correct table name? Check schema

**If tests fail with "401 Unauthorized":**
- ✅ JWT created correctly? (`await createTestJWT()`)
- ✅ JWT secret correct? (Check `.env.local`)
- ✅ Auth header set? (`{ Authorization: jwt }`)

**If tests fail with "RLS policy":**
- ✅ Using service role for setup? (`createTestServiceRoleClient()`)
- ✅ Using user client for test? (`createAuthenticatedClient()`)
- ✅ User ID matches? (JWT userId === inserted user_id)

**If cleanup fails:**
- ✅ Deleting in correct order? (children before parents)
- ✅ Using service role? (bypasses RLS)
- ✅ IDs correct? (return data from setup)

### Success Metrics

After completing all steps:
```bash
cd /Users/anton/ws/mymoney/supabase/functions

# Should all pass
deno task test

# Should show ~80% coverage
deno task coverage

# Should be ~250 lines (down from 638)
wc -l _shared/test-utils.ts

# Should find NO mocks in tests
grep -r "MockQueryBuilder\|createMockSupabaseClient" --include="*.test.ts" .

# Should find real clients
grep -r "createTestSupabaseClient\|createTestServiceRoleClient" --include="*.test.ts" . | wc -l
# Should be many matches (one per test file minimum)
```

---

## 🎓 LEARNING RESOURCES FOR LLM AGENTS

If you need clarification while implementing:

1. **Testing philosophy:** Read "⚠️ MOCKS ARE A LAST RESORT" section above
2. **Example test:** See "Example: auth.test.ts (REWRITTEN)" section
3. **Test template:** See "Test Template (Copy This Pattern)" in Quick Start
4. **Supabase docs:** https://supabase.com/docs/guides/functions/unit-test

**Remember:** If you're about to write `createMock*Client`, STOP and ask yourself:

1. "Why am I not using the real local Supabase instance?" → You should be using real Supabase
2. "Does this API have a free sandbox/test environment?" → Use the sandbox, don't mock
3. "Is this API too expensive or unavailable for testing?" → Only then consider mocking

**Plaid-specific reminder:** Plaid has a free sandbox at sandbox.plaid.com with rich test data. Use it!

**Helpful resources:**
- **Plaid AI Coding Toolkit**: https://github.com/plaid/ai-coding-toolkit/tree/main/sandbox
  - Provides patterns specifically designed for AI agents
  - Shows how to generate mock data, simulate webhooks, test scenarios
  - We've integrated these patterns into our test utilities
- **Official sandbox docs**: https://plaid.com/docs/sandbox/
  - Test institutions, credentials, error scenarios
- **Your credentials** (already in `.env.local`):
  - Client ID: 5cfea7d083a3230012cc3b9d
  - Secret: b9376414937a1160da8e954f6307c8
  - Environment: sandbox

**Quick Plaid patterns:**
```typescript
// Create test item (returns working access_token)
const { access_token, item_id } = await createTestPlaidItem();

// Simulate webhook event
await triggerPlaidSandboxWebhook(access_token, 'DEFAULT_UPDATE');

// Test error states
await resetPlaidSandboxItem(access_token); // Forces re-login
const { access_token: badToken } = await createTestPlaidItem({ testCredentials: 'bad' });
```
