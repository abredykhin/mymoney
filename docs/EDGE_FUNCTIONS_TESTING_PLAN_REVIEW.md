# Edge Functions Testing Plan - Technical Review

**Reviewer:** Senior Engineer Review
**Date:** 2026-01-31
**Document Reviewed:** EDGE_FUNCTIONS_TESTING_PLAN.md v1.0
**Status:** Changes Required Before Implementation

---

## Executive Summary

This testing plan demonstrates solid structure, clear prioritization, and reasonable coverage goals. However, it contains several critical technical gaps that must be addressed before implementation. The primary concerns are incomplete mock utilities, undefined integration testing strategy, and missing infrastructure decisions.

**Overall Assessment:** **NOT READY FOR IMPLEMENTATION**

**Recommendation:** Invest 1-2 days building working versions of test utilities and proving out the mocking strategy with 2-3 real test files before committing to the full 6-week timeline.

---

## Major Issues (Blocking)

### 1. Mock Utilities Are Too Simplistic

**Location:** Section 1.3, Lines 110-210

**Issue:** The `createMockSupabaseClient` implementation won't work with real code patterns. Supabase queries chain multiple methods:

```typescript
const { data, error } = await supabase
  .from('table')
  .select('*')
  .eq('user_id', userId)
  .eq('status', 'active')
  .single();
```

The current mock doesn't support:
- Chaining multiple `.eq()` calls
- Full query builder pattern (`.order()`, `.limit()`, `.range()`, etc.)
- Proper method chaining that returns chainable objects
- Error simulation at different stages

**Impact:** HIGH - Tests will fail or produce false positives

**Recommendation:**
- Build a proper mock that tracks query state through the chain
- Use a builder pattern that accumulates filters
- Support all commonly used query methods in your codebase
- Consider using existing libraries like `@supabase/supabase-js` with a mock implementation layer

**Example of what's needed:**
```typescript
class MockQueryBuilder {
  private filters: Array<{column: string, value: any}> = [];
  private mockData: any[];

  constructor(mockData: any[]) {
    this.mockData = mockData;
  }

  eq(column: string, value: any) {
    this.filters.push({column, value});
    return this; // Return this for chaining
  }

  async single() {
    let filtered = this.mockData;
    for (const filter of this.filters) {
      filtered = filtered.filter(row => row[filter.column] === filter.value);
    }
    return { data: filtered[0] || null, error: null };
  }
}
```

---

### 2. JWT Mocking is a Placeholder

**Location:** Lines 205-209

**Issue:** The mock JWT implementation is literally a placeholder with a TODO comment:
```typescript
export function createMockJWT(userId: string = 'test-user-id'): string {
  // In real tests, you'd use a proper JWT library
  // For now, this is a placeholder
  return `Bearer mock-jwt-token-for-${userId}`;
}
```

Supabase Auth validates JWTs cryptographically. A string "mock-jwt-token" will fail authentication.

**Impact:** HIGH - All authentication tests will fail

**Recommendation:** Choose one approach and document it:

**Option A: Generate Real JWTs**
```typescript
import { create } from "https://deno.land/x/djwt@v2.8/mod.ts";

export async function createMockJWT(userId: string = 'test-user-id'): Promise<string> {
  const secret = Deno.env.get('SUPABASE_JWT_SECRET');
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const jwt = await create(
    { alg: "HS256", typ: "JWT" },
    {
      sub: userId,
      role: "authenticated",
      aud: "authenticated",
      exp: Date.now() / 1000 + 3600
    },
    key
  );

  return `Bearer ${jwt}`;
}
```

**Option B: Mock the Auth Layer Entirely**
- Mock `createAuthenticatedClient()` to bypass JWT validation
- Document that unit tests don't test auth (integration tests would)

---

### 3. Environment Variable Management Missing

**Location:** Not addressed in the plan

**Issue:** No strategy for handling environment variables in tests. Your functions require:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `PLAID_CLIENT_ID`
- `PLAID_SECRET`
- `PLAID_ENV`
- `GEMINI_API_KEY`

**Impact:** HIGH - Tests cannot run without proper env setup

**Recommendation:** Add a new section "Test Environment Setup" that includes:

1. **Create `.env.test` file structure:**
```bash
# supabase/functions/.env.test
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=test-anon-key
SUPABASE_SERVICE_ROLE_KEY=test-service-key
PLAID_CLIENT_ID=test
PLAID_SECRET=test
PLAID_ENV=sandbox
GEMINI_API_KEY=test
```

2. **Load env vars in tests:**
```typescript
// _shared/test-utils.ts
import { load } from "https://deno.land/std@0.224.0/dotenv/mod.ts";

export async function setupTestEnv() {
  await load({ envPath: ".env.test", export: true });
}
```

3. **Document whether to use real or fake values**
- Real values for integration tests against local Supabase
- Fake values for pure unit tests with mocks

---

### 4. Database State Management Undefined

**Location:** Section 2.8-2.11 (Integration Tests)

**Issue:** No plan for managing database state in tests. Critical questions unanswered:
- How do you ensure test isolation?
- Do tests use a real local Supabase instance or mocks?
- How do you reset state between tests?
- What about test data cleanup?
- Race conditions with parallel tests?

**Impact:** HIGH - Integration tests will be flaky or fail

**Recommendation:** Add a dedicated section "Database Testing Strategy" that specifies:

**Option A: Use Real Local Supabase**
```typescript
// Before all tests
Deno.test({
  name: "Database setup",
  async fn() {
    // Ensure supabase is started
    // Run migrations
    // Seed test data
  },
  sanitizeResources: false,
  sanitizeOps: false,
});

// Each test uses transactions that rollback
Deno.test("sync-transactions: full flow", async () => {
  // Start transaction
  const { data: testUser } = await supabase
    .rpc('create_test_user_with_rollback');

  // Run test with testUser.id

  // Transaction auto-rollbacks at end
});
```

**Option B: Mock All Database Calls**
- Document that "integration tests" are really "integration between your modules"
- True database integration happens manually or in E2E tests
- All Supabase calls are mocked in test suite

**Recommendation:** Choose Option A for more confidence, but requires more infrastructure.

---

### 5. Integration vs Unit Testing Boundary Unclear

**Location:** Throughout, especially Section 2.9

**Issue:** The plan mentions "integration tests" but doesn't clearly define the boundary:
- `sync-transactions/index.test.ts` is labeled "Integration Tests"
- But what makes it integration vs unit?
- Does it touch a real database?
- Does it call real Plaid APIs?

**Impact:** MEDIUM - Team confusion, inconsistent test implementation

**Recommendation:** Add a "Testing Philosophy" section with clear definitions:

```markdown
### Testing Layers

**Unit Tests** (majority of tests)
- Test individual functions in isolation
- Mock all external dependencies (Supabase, Plaid, Gemini)
- Fast (<1ms per test)
- Example: `_shared/auth.test.ts`

**Integration Tests** (fewer, focused tests)
- Test multiple modules working together
- May use real local Supabase instance
- Mock only external APIs (Plaid, Gemini)
- Slower (~100ms per test)
- Example: Full sync flow with real DB writes

**E2E Tests** (not covered in this plan)
- Test entire flow from API request to database
- Use real local services
- Run separately from main test suite
```

---

### 6. CI/CD Coverage Enforcement is Incomplete

**Location:** Lines 580-584

**Issue:** The coverage check is literally a TODO:
```yaml
run: |
  # Add script to check if coverage meets minimum threshold
  echo "Coverage check would go here"
```

Without enforcement, your 80% coverage goal is aspirational, not enforced.

**Impact:** MEDIUM - Coverage may slip without team noticing

**Recommendation:** Implement actual coverage threshold check:

```yaml
- name: Check coverage threshold
  working-directory: supabase/functions
  run: |
    deno task test:coverage
    deno task coverage

    # Parse coverage and check threshold
    deno eval "
    const lcov = await Deno.readTextFile('./coverage.lcov');
    const lines = lcov.match(/LF:(\d+)/g).map(l => parseInt(l.split(':')[1]));
    const covered = lcov.match(/LH:(\d+)/g).map(l => parseInt(l.split(':')[1]));
    const totalLines = lines.reduce((a, b) => a + b, 0);
    const totalCovered = covered.reduce((a, b) => a + b, 0);
    const coverage = (totalCovered / totalLines) * 100;

    console.log(\`Coverage: \${coverage.toFixed(2)}%\`);

    if (coverage < 80) {
      console.error('❌ Coverage below 80% threshold');
      Deno.exit(1);
    }
    console.log('✅ Coverage meets 80% threshold');
    "
```

Or use a dedicated tool like `lcov-summary` or integrate with Codecov's threshold features.

---

## Medium Issues (Important)

### 7. Plaid Mock Doesn't Match Real SDK

**Location:** Lines 189-200

**Issue:** The mock signature doesn't match the real Plaid SDK. Real SDK methods take request objects:

```typescript
// Real Plaid SDK
const response = await plaidClient.transactionsSync({
  access_token: accessToken,
  cursor: lastCursor,
  count: 500,
});

// Your mock
transactionsSync: () => Promise.resolve(mockResponses.transactionsSync || {})
```

This type mismatch means tests will pass but production code will break.

**Impact:** MEDIUM - False confidence from passing tests

**Recommendation:** Update mock to match real signatures:

```typescript
export function createMockPlaidClient(mockResponses: Record<string, any>) {
  return {
    linkTokenCreate: (req: LinkTokenCreateRequest) =>
      Promise.resolve(mockResponses.linkTokenCreate || {}),

    itemPublicTokenExchange: (req: ItemPublicTokenExchangeRequest) =>
      Promise.resolve(mockResponses.itemPublicTokenExchange || {}),

    transactionsSync: (req: TransactionsSyncRequest) => {
      // Can validate request parameters in tests
      return Promise.resolve(mockResponses.transactionsSync || {
        added: [],
        modified: [],
        removed: [],
        next_cursor: 'mock-cursor',
        has_more: false,
      });
    },

    // ... etc
  };
}
```

---

### 8. Webhook Signature Testing Needs Detail

**Location:** Lines 260-268

**Issue:** Test cases mention webhook signature validation but don't explain how to generate test signatures. The real validation uses JWT verification with:
- PLAID_WEBHOOK_VERIFICATION_KEY
- Time-based expiry checks
- Body hash verification

**Impact:** MEDIUM - Complex test scenario underspecified

**Recommendation:** Add detailed webhook testing guide:

```typescript
// _shared/test-utils.ts
import { create } from "https://deno.land/x/djwt@v2.8/mod.ts";

export async function createMockWebhookSignature(
  payload: any,
  options: {
    expired?: boolean;
    invalidSignature?: boolean;
    tamperedBody?: boolean;
  } = {}
): Promise<{signature: string, body: string}> {
  const body = JSON.stringify(options.tamperedBody ?
    { ...payload, tampered: true } : payload);

  const now = Math.floor(Date.now() / 1000);
  const issuedAt = options.expired ? now - 400 : now; // >5 min if expired

  const webhookKey = options.invalidSignature ?
    'wrong-key' :
    Deno.env.get('PLAID_WEBHOOK_VERIFICATION_KEY');

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(webhookKey),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const token = await create(
    { alg: "HS256" },
    {
      request_body_sha256: await hashSHA256(body),
      iat: issuedAt
    },
    key
  );

  return { signature: token, body };
}
```

---

### 9. Missing Test Data Strategy

**Location:** Not addressed

**Issue:** No plan for test fixtures, seed data, or reusable datasets. Every test will need to create its own test data, leading to duplication and inconsistency.

**Impact:** MEDIUM - Test maintenance burden, inconsistent test data

**Recommendation:** Create a fixtures directory:

```
supabase/functions/_shared/fixtures/
├── institutions.json
├── accounts.json
├── transactions.json
├── plaid-responses.json
└── budget-items.json
```

Example fixture:
```typescript
// _shared/fixtures/transactions.json
export const mockTransactions = [
  {
    transaction_id: "plaid_tx_1",
    account_id: "plaid_acc_1",
    amount: 4.99,
    date: "2026-01-15",
    name: "Netflix",
    merchant_name: "Netflix",
    category: ["Entertainment", "Streaming"],
    pending: false
  },
  // ... more realistic test data
];
```

And a fixture loader:
```typescript
// _shared/test-utils.ts
export async function loadFixture<T>(name: string): Promise<T> {
  const path = new URL(`./fixtures/${name}.json`, import.meta.url);
  const content = await Deno.readTextFile(path);
  return JSON.parse(content);
}
```

---

### 10. Retry Logic Testing Underspecified

**Location:** Lines 369, 388, 410

**Issue:** Functions have exponential backoff for rate limits, but no guidance on testing time-dependent behavior without waiting actual seconds.

**Impact:** MEDIUM - Slow tests or untested retry logic

**Recommendation:** Document use of Deno's fake timers:

```typescript
import { FakeTime } from "https://deno.land/std@0.224.0/testing/time.ts";

Deno.test("transactionsSync: retries with exponential backoff", async () => {
  const time = new FakeTime();

  try {
    let callCount = 0;
    const mockPlaidClient = {
      transactionsSync: async () => {
        callCount++;
        if (callCount < 3) {
          throw new Error("RATE_LIMIT");
        }
        return { added: [], modified: [], removed: [] };
      }
    };

    // Start async operation
    const promise = syncTransactions(mockPlaidClient, "access_token");

    // Fast-forward through retries
    await time.tickAsync(1000);  // First retry after 1s
    await time.tickAsync(2000);  // Second retry after 2s

    const result = await promise;

    assertEquals(callCount, 3);
    assertExists(result);
  } finally {
    time.restore();
  }
});
```

---

### 11. Performance Testing Missing

**Location:** Not mentioned

**Issue:** No mention of performance benchmarks, especially for data-intensive operations:
- `sync-transactions` with thousands of transactions
- `gemini-budget-analysis` with 90 days of data
- Batch database operations

**Impact:** MEDIUM - Performance regressions may go unnoticed

**Recommendation:** Add a "Performance Testing" section:

```markdown
### Performance Benchmarks

Create `*.bench.ts` files for performance-critical operations:

```typescript
// sync-transactions/plaid.bench.ts
Deno.bench("fetchTransactionUpdates: 1000 transactions", async () => {
  const mockClient = createMockPlaidClient({
    transactionsSync: {
      added: Array(1000).fill(mockTransaction),
      modified: [],
      removed: [],
    }
  });

  await fetchTransactionUpdates(mockClient, "access_token");
});
```

Run with: `deno bench --allow-env --allow-net`

**Performance Targets:**
- Transaction sync: <5s for 1000 transactions
- Budget analysis: <10s for 90 days of data
- Database batch operations: <2s for 100 records
```

---

### 12. Gemini AI Testing Strategy Missing

**Location:** Not specifically addressed (mentioned in 2.10)

**Issue:** The `gemini-budget-analysis` function uses AI with non-deterministic output. This requires a unique testing approach:
- Mock responses may not match real AI behavior
- Confidence scores need validation
- Post-processing logic needs thorough testing
- Edge cases (malformed AI output, unexpected categories)

**Impact:** MEDIUM - AI-powered feature may be undertested

**Recommendation:** Add dedicated section "Testing AI-Powered Functions":

```markdown
### Testing Gemini Budget Analysis

**Challenge:** AI responses are non-deterministic and expensive to call in tests.

**Strategy:**

1. **Mock Gemini API with realistic responses:**
```typescript
// _shared/fixtures/gemini-responses.json
export const mockGeminiResponse = {
  "recurring_items": [
    {
      "name": "Netflix Subscription",
      "pattern": "Netflix",
      "amount": 15.99,
      "frequency": "MONTHLY",
      "type": "fixed_expense",
      "confidence": 0.95,
      "last_seen_date": "2026-01-15"
    }
    // ... more items
  ]
};
```

2. **Test post-processing logic extensively:**
- Malformed AI responses (missing fields, wrong types)
- Confidence score filtering (>= 0.85 threshold)
- Pattern extraction and false positive filtering
- Edge cases: no recurring items found, all low confidence

3. **Manual verification tests:**
- Run with real API occasionally to verify mock realism
- Document any divergence between mock and real behavior

4. **Test prompts separately:**
- Verify prompt construction logic
- Ensure transaction filtering before sending to AI
```

---

## Minor Issues & Improvements

### 13. Timeline Inconsistency

**Location:** Section 4 vs Section 6

**Issue:**
- Section 4 (Coverage Goals): Shows 5-week timeline
- Section 6 (Implementation Timeline): Shows 6-week timeline with 54-67 hours

**Impact:** LOW - Confusion about actual timeline

**Recommendation:** Reconcile to single timeline. If 6 weeks is correct, update Section 4's table.

---

### 14. Version Pinning Strategy Missing

**Location:** Throughout (using `std@0.224.0`)

**Issue:** No documentation on:
- How often to update standard library versions
- Handling breaking changes
- Dependency management strategy
- Should versions be locked or use ranges?

**Impact:** LOW - Future maintenance clarity

**Recommendation:** Add "Dependency Management" section:

```markdown
### Dependency Management

**Current Versions:**
- Deno std: `0.224.0` (locked)
- djwt: `v2.8` (locked)

**Update Policy:**
- Review dependencies monthly
- Test suite must pass before updating
- Update lockfile: `deno cache --lock=deno.lock --lock-write **/*.ts`

**Breaking Changes:**
- Pin major versions
- Document migration path when updating
- Run full test suite before merging updates
```

---

### 15. Parallel Test Execution Not Addressed

**Location:** Not mentioned

**Issue:** Deno runs tests in parallel by default. This can cause:
- Database state conflicts
- Race conditions in integration tests
- Resource contention

**Impact:** LOW - May cause flaky tests

**Recommendation:** Document parallel execution strategy:

```markdown
### Parallel Test Execution

Deno runs tests in parallel by default. To ensure test isolation:

**For unit tests:** No changes needed (fully isolated with mocks)

**For integration tests:** Use one of these strategies:

1. **Isolate by user ID:**
```typescript
Deno.test("sync-transactions: test 1", async () => {
  const userId = `test-user-${crypto.randomUUID()}`;
  // Create isolated test data for this user
});
```

2. **Run sequentially:**
```typescript
Deno.test({
  name: "sync-transactions: database integration",
  fn: async () => { /* test */ },
  sanitizeResources: false,
  sanitizeOps: false,
  // Note: Use test dependencies to enforce ordering if needed
});
```

3. **Use test permissions:**
```bash
deno test --allow-env --allow-net --jobs=1  # Sequential execution
```
```

---

### 16. Security Testing Absent

**Location:** Not mentioned

**Issue:** No plan for security-focused testing:
- RLS (Row Level Security) policy validation
- Authentication bypass attempts
- Authorization checks (user can only see their data)
- Input validation and sanitization
- SQL injection attempts

**Impact:** MEDIUM - Security vulnerabilities may slip through

**Recommendation:** Add "Security Testing" section:

```markdown
### Security Testing

**Critical Security Test Cases:**

1. **RLS Validation:**
```typescript
Deno.test("accounts: RLS prevents cross-user access", async () => {
  const user1Client = createAuthenticatedClient(user1JWT);
  const user2Client = createAuthenticatedClient(user2JWT);

  // User 1 creates account
  await user1Client.from('accounts').insert({ name: 'User 1 Account' });

  // User 2 should not see User 1's accounts
  const { data } = await user2Client.from('accounts').select('*');

  assertEquals(data.length, 0);
});
```

2. **Authorization Tests:**
- Test service role vs authenticated user permissions
- Verify functions check user ownership before operations
- Test webhook endpoints require valid signatures

3. **Input Validation:**
- Test with malformed JSON
- Test with SQL-like strings
- Test with extremely large payloads
- Test with missing required fields

**Run with:** `deno task test:security`
```

---

### 17. Error Scenarios Underdeveloped

**Location:** Throughout test cases

**Issue:** Error path testing is mentioned but not detailed. Need specific scenarios:
- Network timeouts
- Partial failures (some accounts succeed, others fail)
- Database constraint violations
- Race conditions
- Plaid API errors (ITEM_LOGIN_REQUIRED, RATE_LIMIT, etc.)

**Impact:** MEDIUM - Important error paths may be undertested

**Recommendation:** Create error scenario matrix as appendix:

```markdown
## Appendix C: Error Scenario Matrix

| Function | Error Type | Test Case | Priority |
|----------|------------|-----------|----------|
| save-item | Duplicate item_id | Should return existing item | P1 |
| save-item | Plaid token exchange fails | Should return error, no DB changes | P1 |
| save-item | Institution fetch fails | Should save item without logo | P2 |
| sync-transactions | ITEM_LOGIN_REQUIRED | Should mark item as requires_relink | P1 |
| sync-transactions | Network timeout | Should retry with backoff | P1 |
| sync-transactions | Partial page failure | Should save successful pages | P2 |
| plaid-webhook | Invalid signature | Should return 401 | P1 |
| plaid-webhook | Malformed payload | Should return 200 (prevent retries) | P1 |
| gemini-budget | API quota exceeded | Should fail gracefully, log error | P2 |
| gemini-budget | Malformed AI response | Should skip item, not crash | P1 |

Track coverage: ✅ Tested | ⏳ In Progress | ❌ Not Tested
```

---

### 18. Test Maintainability Strategy

**Location:** Section 11 (superficial coverage)

**Issue:** Mentions "update mocks when APIs change" but doesn't explain how to detect API changes or keep mocks in sync.

**Impact:** LOW - Long-term maintenance burden

**Recommendation:** Add contract testing strategy:

```markdown
### Keeping Mocks in Sync

**Problem:** Real APIs change, mocks become stale, tests pass but production breaks.

**Solutions:**

1. **API Version Pinning:**
```typescript
// _shared/plaid.ts
const PLAID_API_VERSION = '2020-09-14';
```
Document version in test fixtures, update together.

2. **Smoke Tests (Manual):**
Run quarterly against real APIs to verify mock accuracy:
```bash
deno task test:smoke  # Uses real Plaid sandbox, real local Supabase
```

3. **Schema Validation:**
Use Zod or similar to define API response schemas:
```typescript
const PlaidAccountSchema = z.object({
  account_id: z.string(),
  balances: z.object({
    available: z.number().nullable(),
    current: z.number(),
  }),
  // ... full schema
});

// In tests, validate mock data
PlaidAccountSchema.parse(mockAccount); // Throws if invalid
```

4. **Changelog Monitoring:**
- Subscribe to Plaid API changelog
- Review Supabase release notes
- Update mocks proactively when API changes are announced
```

---

## Structural Improvements

### 19. Missing Sections

**Impact:** LOW-MEDIUM - Reduced plan clarity and completeness

**Recommendation:** Add these sections:

1. **Testing Philosophy** (after Overview)
- Test pyramid diagram
- When to mock vs integrate
- Definition of unit vs integration vs E2E
- Testing principles (isolation, repeatability, speed)

2. **Local Environment Setup** (before Section 1)
- Prerequisites (Deno, Supabase CLI versions)
- Step-by-step setup instructions
- How to verify setup is working
- Troubleshooting common issues

3. **Troubleshooting Guide** (as Appendix)
- Common test failures and solutions
- "Tests pass locally but fail in CI"
- "Flaky test debugging"
- "Mock not working as expected"

4. **Test Data Management** (as Section 2.1.5)
- Fixture directory structure
- How to create new fixtures
- Fixture naming conventions
- When to use fixtures vs inline data

---

### 20. Example Test File Issues

**Location:** Appendix A (Lines 762-833)

**Issue:** Example test is too basic. Doesn't demonstrate:
- Complex Supabase query chaining
- Async background processing (`ctx.waitUntil`)
- Proper error testing with meaningful assertions
- Realistic test data
- Mock setup for complex scenarios

**Impact:** LOW - Developers may not understand how to write real tests

**Recommendation:** Replace with comprehensive example:

```typescript
// Appendix A: Comprehensive Test Example

// sync-transactions/database.test.ts
import {
  assertEquals,
  assertExists,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  upsertAccounts,
  insertTransactions,
  updateSyncCursor
} from "./database.ts";
import {
  createMockSupabaseClient,
  loadFixture
} from "../_shared/test-utils.ts";

// Test suite for account upsert logic
Deno.test("upsertAccounts: should insert new accounts and update existing", async () => {
  // Arrange
  const mockAccounts = await loadFixture('accounts');
  const existingAccount = mockAccounts[0];
  const newAccount = { ...mockAccounts[1], account_id: 'new_account' };

  const mockSupabase = createMockSupabaseClient({
    accounts: [existingAccount] // Simulate existing data
  });

  // Act
  const result = await upsertAccounts(
    mockSupabase,
    [existingAccount, newAccount],
    'test-item-id'
  );

  // Assert
  assertExists(result);
  assertEquals(result.length, 2);
  assertEquals(result[0].account_id, existingAccount.account_id);
  assertEquals(result[1].account_id, newAccount.account_id);
});

// Test suite for error handling
Deno.test("insertTransactions: should handle database constraint violation", async () => {
  // Arrange
  const mockSupabase = createMockSupabaseClient({
    transactions: {
      // Simulate constraint error
      error: { code: '23505', message: 'duplicate key' }
    }
  });

  const transactions = await loadFixture('transactions');

  // Act & Assert
  await assertRejects(
    async () => await insertTransactions(mockSupabase, transactions),
    Error,
    'duplicate key'
  );
});

// Test suite for complex query chaining
Deno.test("updateSyncCursor: should update cursor with proper filtering", async () => {
  // Arrange
  let capturedQuery: any;
  const mockSupabase = {
    from: (table: string) => ({
      update: (data: any) => ({
        eq: (column: string, value: any) => ({
          eq: (column2: string, value2: any) => {
            // Capture the full query for verification
            capturedQuery = { table, data, filters: [
              { column, value },
              { column: column2, value: value2 }
            ]};
            return { data: [{ id: 'test' }], error: null };
          }
        })
      })
    })
  };

  // Act
  await updateSyncCursor(
    mockSupabase as any,
    'test-item-id',
    'new-cursor-value'
  );

  // Assert
  assertEquals(capturedQuery.table, 'items');
  assertEquals(capturedQuery.data.cursor, 'new-cursor-value');
  assertEquals(capturedQuery.filters[0].column, 'item_id');
  assertEquals(capturedQuery.filters[0].value, 'test-item-id');
});
```

---

## Action Items (Prioritized)

### Critical (Must Fix Before Starting)

1. **Build working mock utilities** (2-3 days)
   - Implement proper `MockQueryBuilder` with chaining
   - Implement real JWT generation or auth layer mocking
   - Test mocks with actual function code to verify they work

2. **Define integration testing strategy** (1 day)
   - Decide: Local Supabase instance or full mocking?
   - Document database state management
   - Create setup/teardown procedures

3. **Complete CI/CD implementation** (4 hours)
   - Implement coverage threshold check
   - Test GitHub Actions workflow locally
   - Verify it fails when coverage drops

4. **Create environment setup guide** (2 hours)
   - Document all required env vars
   - Create `.env.test` template
   - Write step-by-step local setup instructions

### High Priority (First Week)

5. **Fix Plaid mock signatures** (2 hours)
   - Match real Plaid SDK method signatures
   - Add type checking where possible

6. **Create test fixtures** (4 hours)
   - Build fixtures directory structure
   - Create realistic test data for institutions, accounts, transactions
   - Create fixture loader utility

7. **Document test data strategy** (2 hours)
   - When to use fixtures vs inline data
   - How to maintain fixtures
   - Fixture naming conventions

8. **Add security testing section** (2 hours)
   - Document RLS testing approach
   - Create authorization test template
   - Add to test plan timeline

### Medium Priority (During Implementation)

9. **Add webhook signature testing guide** (3 hours)
   - Implement `createMockWebhookSignature` utility
   - Document time-based expiry testing
   - Create example webhook tests

10. **Document parallel execution strategy** (1 hour)
    - Explain Deno's default behavior
    - Document isolation techniques
    - Update test configuration

11. **Add Gemini AI testing strategy** (2 hours)
    - Document AI response mocking approach
    - Create realistic mock responses
    - Add edge case test scenarios

12. **Create error scenario matrix** (3 hours)
    - List all error types per function
    - Prioritize test coverage
    - Add to appendix

### Low Priority (Polish Phase)

13. **Add performance testing section** (2 hours)
    - Document benchmarking approach
    - Set performance targets
    - Create example benchmark tests

14. **Fix timeline consistency** (15 minutes)
    - Reconcile 5 vs 6 week timeline
    - Ensure hours estimate matches weeks

15. **Add dependency management section** (1 hour)
    - Document version pinning strategy
    - Create update policy
    - Add to maintenance section

16. **Expand example test file** (2 hours)
    - Replace basic example with comprehensive one
    - Show complex query chaining
    - Demonstrate async testing patterns

17. **Add test maintainability guide** (2 hours)
    - Contract testing strategy
    - Mock sync procedures
    - API changelog monitoring

18. **Add troubleshooting guide** (2 hours)
    - Common failures and solutions
    - Flaky test debugging
    - CI vs local differences

---

## Revised Timeline Estimate

Given the critical issues identified, here's a more realistic timeline:

| Phase | Duration | Activities |
|-------|----------|-----------|
| **Pre-Implementation** | **1-2 weeks** | Fix critical issues 1-4, complete infrastructure |
| Infrastructure | 1 week | Mock utilities, env setup, CI/CD |
| Shared Utilities | 1 week | auth.ts, plaid.ts, recurring.ts tests |
| Simple Functions | 1.5 weeks | 3 simple function test suites |
| Complex Functions | 2.5 weeks | 4 complex function test suites |
| Polish & Documentation | 1 week | Hit 80% coverage, docs, troubleshooting |
| **Total** | **7-8 weeks** | Including pre-implementation work |

**Total Estimated Effort:** 70-85 hours (up from 54-67 hours)

---

## Final Recommendation

This testing plan has good structure and comprehensive coverage of what needs testing, but lacks critical implementation details that will cause blockers during execution.

**Immediate Next Steps:**

1. **Proof of Concept (2-3 days):**
   - Build working versions of all mock utilities
   - Write 3-5 real test cases using these mocks
   - Verify they work with actual function code
   - This will validate the entire approach

2. **Revise Plan (1 day):**
   - Update mock implementations in the plan
   - Add missing sections (environment setup, security testing, etc.)
   - Clarify integration vs unit testing strategy
   - Complete CI/CD implementation details

3. **Get Approval (1 day):**
   - Review revised plan with team
   - Ensure infrastructure decisions are aligned with team preferences
   - Confirm timeline and resource allocation

4. **Begin Implementation:**
   - Start with Week 1 infrastructure (now on solid foundation)
   - Follow prioritized approach as outlined

**Do not start the 6-week implementation timeline until the Proof of Concept validates the approach.**

---

## Conclusion

The planning effort here is commendable and shows good understanding of testing principles and Deno/Supabase ecosystem. However, software engineering requires working implementations, not just plans. The gap between "create a mock" and "create a mock that actually works with our code" is where most test initiatives fail.

Invest the upfront time to build working infrastructure before committing to the full timeline. The 2-3 days spent on proof of concept will save weeks of rework later.

**Overall Grade:** B- (Good structure, incomplete implementation details)
**Readiness for Implementation:** Not Ready (Complete critical action items first)
**Confidence in Timeline:** Low → Medium (after POC), Medium → High (after revisions)
