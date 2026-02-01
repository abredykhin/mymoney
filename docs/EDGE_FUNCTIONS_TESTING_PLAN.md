# Edge Functions Testing Plan

## Overview

This document outlines a comprehensive testing strategy for the Supabase Edge Functions backend. Currently, only one function has tests (`sync-transactions/database.test.ts` with 15 tests). This plan will establish a robust testing framework covering all 7 edge functions and 3 shared utility modules.

**Current State:**
- 7 edge functions with 3,284 lines of code
- 1 test file (15 tests in `database.test.ts`)
- No standardized testing infrastructure

**Goal State:**
- 80%+ code coverage across all functions
- Standardized testing patterns
- CI/CD integration
- Fast, reliable test suite (<30 seconds runtime)

---

## Research Findings Summary

Your backend has **7 edge functions** with **3,284 lines of code**. The good news is that Deno has excellent built-in testing support, and your existing test file demonstrates the patterns we should follow.

**Key Resources:**
- [Testing your Edge Functions | Supabase Docs](https://supabase.com/docs/guides/functions/unit-test)
- [Testing Supabase Edge Functions with Deno Test](https://blog.mansueli.com/testing-supabase-edge-functions-with-deno-test)
- [Writing tests | Deno Docs](https://docs.deno.com/examples/testing_tutorial/)
- [Testing | Deno Fundamentals](https://docs.deno.com/runtime/fundamentals/testing/)
- [Testing in isolation with mocks | Deno Docs](https://docs.deno.com/examples/mocking_tutorial/)

---

## 1. Test Infrastructure Setup

### 1.1 Directory Structure

Following Supabase's recommendations, reorganize tests by co-locating them with the modules they test:

```
supabase/functions/
├── _shared/
│   ├── auth.ts
│   ├── auth.test.ts           # NEW
│   ├── plaid.ts
│   ├── plaid.test.ts          # NEW
│   ├── recurring.ts
│   ├── recurring.test.ts      # NEW
│   └── test-utils.ts          # NEW - Shared test utilities
├── plaid-link-token/
│   ├── index.ts
│   └── index.test.ts          # NEW
├── save-item/
│   ├── index.ts
│   └── index.test.ts          # NEW
├── sync-transactions/
│   ├── index.ts
│   ├── index.test.ts          # NEW (integration tests)
│   ├── database.ts
│   ├── database.test.ts       # EXISTS (15 tests)
│   ├── plaid.ts
│   ├── plaid.test.ts          # NEW
│   └── types.ts
├── plaid-webhook/
│   ├── index.ts
│   └── index.test.ts          # NEW
├── sync-recurring-transactions/
│   ├── index.ts
│   └── index.test.ts          # NEW
├── create-manual-stream/
│   ├── index.ts
│   └── index.test.ts          # NEW
└── update-webhooks/
    ├── index.ts
    └── index.test.ts          # NEW
```

**Rationale:**
- Co-locate unit tests with the modules they test
- Makes tests easy to discover and maintain
- Simplifies imports (relative paths)
- Follows Deno and Supabase best practices

### 1.2 Test Configuration Files

Create `supabase/functions/deno.jsonc`:

```jsonc
{
  "tasks": {
    "test": "deno test --allow-env --allow-net --allow-read",
    "test:watch": "deno test --allow-env --allow-net --allow-read --watch",
    "test:coverage": "deno test --allow-env --allow-net --allow-read --coverage=coverage",
    "test:unit": "deno test --allow-env --ignore=**/*integration*.test.ts",
    "coverage": "deno coverage coverage --lcov --output=coverage.lcov"
  },
  "exclude": ["coverage/"]
}
```

**Rationale:**
- Standardized test commands across team
- Easy to run specific test suites
- Coverage reporting for tracking progress
- Can filter integration vs unit tests

### 1.3 Shared Test Utilities

Create `supabase/functions/_shared/test-utils.ts`:

```typescript
import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";

/**
 * Creates a mock Supabase client for testing
 * @param mockData - Object with table names as keys and mock data as values
 */
export function createMockSupabaseClient(mockData: Record<string, any>) {
  return {
    from: (table: string) => ({
      select: (columns?: string) => ({
        data: mockData[table] || [],
        error: null
      }),
      insert: (data: any) => ({
        data: data,
        error: null
      }),
      upsert: (data: any) => ({
        data: data,
        error: null
      }),
      update: (data: any) => ({
        data: data,
        error: null
      }),
      delete: () => ({
        data: null,
        error: null
      }),
      eq: (column: string, value: any) => ({
        select: () => ({
          data: mockData[table]?.filter((row: any) => row[column] === value) || [],
          error: null
        }),
        single: () => ({
          data: mockData[table]?.find((row: any) => row[column] === value) || null,
          error: null
        }),
      }),
      single: () => ({
        data: mockData[table]?.[0] || null,
        error: null
      }),
    }),
    auth: {
      getUser: () => ({
        data: { user: mockData.user || { id: 'test-user-id' } },
        error: null
      }),
    },
    rpc: (fn: string, params?: any) => ({
      data: mockData[fn] || null,
      error: null
    }),
  };
}

/**
 * Creates a mock Request object for testing
 */
export function createMockRequest(options: {
  method?: string;
  url?: string;
  headers?: Record<string, string>;
  body?: any;
}): Request {
  const { method = 'GET', url = 'http://localhost', headers = {}, body } = options;

  return new Request(url, {
    method,
    headers: new Headers(headers),
    body: body ? JSON.stringify(body) : undefined,
  });
}

/**
 * Creates a mock Plaid client for testing
 */
export function createMockPlaidClient(mockResponses: Record<string, any>) {
  return {
    linkTokenCreate: () => Promise.resolve(mockResponses.linkTokenCreate || {}),
    itemPublicTokenExchange: () => Promise.resolve(mockResponses.itemPublicTokenExchange || {}),
    institutionsGetById: () => Promise.resolve(mockResponses.institutionsGetById || {}),
    accountsGet: () => Promise.resolve(mockResponses.accountsGet || {}),
    transactionsSync: () => Promise.resolve(mockResponses.transactionsSync || {}),
    accountsBalanceGet: () => Promise.resolve(mockResponses.accountsBalanceGet || {}),
    transactionsRecurringGet: () => Promise.resolve(mockResponses.transactionsRecurringGet || {}),
    itemWebhookUpdate: () => Promise.resolve(mockResponses.itemWebhookUpdate || {}),
  };
}

/**
 * Helper to create a JWT token for testing
 */
export function createMockJWT(userId: string = 'test-user-id'): string {
  // In real tests, you'd use a proper JWT library
  // For now, this is a placeholder
  return `Bearer mock-jwt-token-for-${userId}`;
}
```

---

## 2. Testing Strategy by Priority

### Priority 1: Shared Utilities (Foundation) - Weeks 1-2

These are used by all functions, so testing them first provides maximum value.

#### 2.1 `_shared/auth.test.ts` (Low Complexity, High Impact)

**Target Coverage: 90%+**

**Test Cases:**
- ✅ `createAuthenticatedClient()` with valid JWT
- ✅ `createAuthenticatedClient()` with invalid JWT
- ✅ `createServiceRoleClient()` initialization
- ✅ `getAuthenticatedUser()` extracts correct user
- ✅ `requireAuth()` returns 401 for missing auth
- ✅ `handleCors()` returns correct preflight response
- ✅ `jsonResponse()` includes CORS headers
- ✅ Environment variable fallback logic (CUSTOM_ prefix)

**Mocking Strategy:**
- Mock `createClient()` from Supabase
- Mock `Request` objects with Authorization headers
- Use Deno's built-in mocking

**Example Test:**
```typescript
Deno.test("requireAuth: should return 401 for missing Authorization header", async () => {
  const request = createMockRequest({ method: 'GET' });
  const response = await requireAuth(request);

  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.error, 'Missing authorization header');
});
```

#### 2.2 `_shared/plaid.test.ts` (Medium Complexity)

**Target Coverage: 85%+**

**Test Cases:**
- ✅ `getPlaidConfig()` reads environment correctly
- ✅ `getPlaidConfig()` throws on missing credentials
- ✅ `createPlaidClient()` returns configured client
- ✅ `handlePlaidError()` formats different error types
- ✅ `validateWebhookSignature()` accepts valid signature
- ✅ `validateWebhookSignature()` rejects expired webhook (>5 min)
- ✅ `validateWebhookSignature()` rejects invalid signature
- ✅ `validateWebhookSignature()` rejects body tampering

**Mocking Strategy:**
- Mock Plaid API responses
- Mock JWT verification with jose library
- Create test webhook payloads with valid/invalid signatures

#### 2.3 `_shared/recurring.test.ts` (Low Complexity)

**Target Coverage: 90%+**

**Test Cases:**
- ✅ `updateTransactionRecurringFlags()` marks correct transactions
- ✅ `updateTransactionRecurringFlags()` respects is_active flag
- ✅ `updateTransactionRecurringFlags()` respects TOMBSTONE status
- ✅ `updateProfileRecurringSummary()` calculates correct totals
- ✅ `updateProfileRecurringSummary()` separates income/expenses

**Mocking Strategy:**
- Mock Supabase client with fake data
- Use existing pattern from `database.test.ts`

---

### Priority 2: Simple Functions (Quick Wins) - Week 3

#### 2.4 `plaid-link-token/index.test.ts`

**Target Coverage: 80%+**

**Test Cases:**
- ✅ New link mode: generates token with correct config
- ✅ Update mode: includes access_token for existing item
- ✅ Authentication failure returns 401
- ✅ Local dev mode bypasses auth
- ✅ Missing itemId in update mode returns error
- ✅ Plaid error handling

**Mocking Strategy:**
- Mock `plaidClient.linkTokenCreate()`
- Mock database queries for item lookup
- Mock authentication

#### 2.5 `create-manual-stream/index.test.ts`

**Target Coverage: 80%+**

**Test Cases:**
- ✅ Creates stream from transaction
- ✅ Pattern extraction logic works correctly
- ✅ Duplicate stream detection
- ✅ Matches related transactions by pattern
- ✅ Updates profile summary after creation
- ✅ Frequency conversion (WEEKLY → monthly amount)

**Mocking Strategy:**
- Mock transaction and account fetches
- Mock database inserts
- Test pattern extraction as pure function

#### 2.6 `update-webhooks/index.test.ts`

**Target Coverage: 80%+**

**Test Cases:**
- ✅ Updates all active items
- ✅ Service role auth required
- ✅ Returns summary with success/failure counts
- ✅ Handles Plaid API errors gracefully

**Mocking Strategy:**
- Mock Plaid `itemWebhookUpdate()` calls
- Mock database queries for items

---

### Priority 3: Complex Functions (Core Logic) - Weeks 4-5

#### 2.7 `save-item/index.test.ts`

**Target Coverage: 75%+**

**Test Cases:**
- ✅ Full flow: public token → access token → save item
- ✅ Duplicate item detection
- ✅ Institution upsert logic
- ✅ Account creation
- ✅ Initial sync trigger (fire-and-forget)
- ✅ Error handling for each step
- ✅ RLS compliance (user_id filtering)

**Mocking Strategy:**
- Mock Plaid token exchange
- Mock Plaid institution fetch
- Mock Plaid accounts fetch
- Mock database operations
- Mock function invocations (sync-transactions)

#### 2.8 `sync-transactions/plaid.test.ts` (New File)

**Target Coverage: 85%+**

**Test Cases:**
- ✅ `fetchTransactionUpdates()` handles pagination
- ✅ `fetchTransactionUpdates()` handles rate limits
- ✅ `fetchAccountBalances()` returns correct data
- ✅ Exponential backoff logic

**Mocking Strategy:**
- Mock Plaid API responses
- Simulate rate limit responses (429)
- Test retry logic

#### 2.9 `sync-transactions/index.test.ts` (Integration Tests)

**Target Coverage: 75%+**

**Note:** `database.test.ts` already exists with 15 tests for database operations.

**Additional Coverage Needed:**
- ✅ Full sync flow with pagination
- ✅ Cursor management (only updated on success)
- ✅ Account ID mapping logic
- ✅ Batch operations execution order
- ✅ Historical sync completion logic
- ✅ Recurring sync trigger conditions
- ✅ Rate limit retry logic
- ✅ ITEM_LOGIN_REQUIRED handling
- ✅ Network timeout handling

**Mocking Strategy:**
- Mock Plaid `/transactions/sync` responses
- Mock Plaid `/accounts/balance/get` responses
- Mock database operations (or use existing tests)
- Test retry logic with controlled failures

#### 2.10 `sync-recurring-transactions/index.test.ts`

**Target Coverage: 75%+**

**Test Cases:**
- ✅ Processes inflow and outflow streams
- ✅ Frequency conversion logic
- ✅ Preserves user overrides (user_marked_recurring, is_excluded)
- ✅ Manual stream pattern matching
- ✅ Transaction linking logic
- ✅ Profile summary update
- ✅ Rate limit handling

**Mocking Strategy:**
- Mock Plaid `/transactions/recurring/get`
- Mock database queries and upserts
- Test frequency calculations as pure functions

#### 2.11 `plaid-webhook/index.test.ts`

**Target Coverage: 75%+**

**Test Cases:**
- ✅ Webhook signature verification
- ✅ TRANSACTIONS webhooks trigger sync
- ✅ RECURRING_TRANSACTIONS_UPDATE trigger
- ✅ ITEM error handling
- ✅ Returns 200 for invalid payloads (prevent retries)
- ✅ Returns 401 for invalid signatures
- ✅ Background processing (ctx.waitUntil)
- ✅ Local dev mode bypasses verification

**Mocking Strategy:**
- Create valid webhook payloads
- Mock signature verification
- Mock function invocations
- Test async background processing

---

## 3. Testing Patterns & Best Practices

### 3.1 Test Naming Convention

Follow Deno best practices:

```typescript
Deno.test("functionName: should do X when Y", async () => {
  // Arrange - Set up test data and mocks
  const mockData = { ... };

  // Act - Execute the function under test
  const result = await functionName(mockData);

  // Assert - Verify the result
  assertEquals(result, expectedValue);
});
```

### 3.2 Assertion Library

Use Deno's standard assertions:

```typescript
import {
  assertEquals,
  assertExists,
  assertRejects,
  assertStrictEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
```

**Best Practices:**
- Use `assertStrictEquals()` for precise comparisons
- Use `assertEquals()` for general comparisons
- Use `assertRejects()` for async error testing
- Use `assertExists()` to check for null/undefined

### 3.3 Mocking Strategy

**What to Mock:**
- ✅ External API calls (Plaid)
- ✅ Database operations (Supabase)
- ✅ Network requests
- ✅ Environment variables

**What NOT to Mock:**
- ❌ Your own utility functions
- ❌ Pure functions (test them directly)
- ❌ Simple data transformations

### 3.4 Test Organization

**File Structure:**
```typescript
// Imports
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { functionToTest } from "./index.ts";
import { createMockSupabaseClient } from "../_shared/test-utils.ts";

// Test suite for a specific function or feature
Deno.test("Feature: Happy path", async () => { ... });
Deno.test("Feature: Error handling", async () => { ... });
Deno.test("Feature: Edge cases", async () => { ... });
```

---

## 4. Coverage Goals

| Component | Target Coverage | Priority | Timeline |
|-----------|----------------|----------|----------|
| `_shared/auth.ts` | 90%+ | P1 | Week 1 |
| `_shared/plaid.ts` | 85%+ | P1 | Week 1 |
| `_shared/recurring.ts` | 90%+ | P1 | Week 2 |
| `plaid-link-token/` | 80%+ | P2 | Week 3 |
| `create-manual-stream/` | 80%+ | P2 | Week 3 |
| `update-webhooks/` | 80%+ | P2 | Week 3 |
| `save-item/` | 75%+ | P3 | Week 4 |
| `sync-transactions/` | 75%+ | P3 | Week 4-5 |
| `sync-recurring-transactions/` | 75%+ | P3 | Week 5 |
| `plaid-webhook/` | 75%+ | P3 | Week 5 |
| **Overall Target** | **80%+** | - | **End of Week 5** |

**Rationale:**
- Shared utilities get highest coverage (used everywhere)
- Complex functions may have harder-to-test error paths
- Focus on critical business logic over edge cases

---

## 5. CI/CD Integration

### 5.1 GitHub Actions Workflow

Create `.github/workflows/test-edge-functions.yml`:

```yaml
name: Test Edge Functions

on:
  push:
    branches: [main]
    paths:
      - 'supabase/functions/**'
  pull_request:
    branches: [main]
    paths:
      - 'supabase/functions/**'

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Deno
        uses: denoland/setup-deno@v1
        with:
          deno-version: v1.x

      - name: Run tests
        working-directory: supabase/functions
        run: deno task test

      - name: Generate coverage report
        working-directory: supabase/functions
        run: |
          deno task test:coverage
          deno task coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./supabase/functions/coverage.lcov
          flags: edge-functions
          fail_ci_if_error: false

      - name: Check coverage threshold
        working-directory: supabase/functions
        run: |
          # Add script to check if coverage meets minimum threshold
          echo "Coverage check would go here"
```

### 5.2 Pre-commit Hook (Optional)

Add to `.git/hooks/pre-commit` or use Husky:

```bash
#!/bin/bash
echo "Running Edge Functions tests..."
cd supabase/functions
deno task test

if [ $? -ne 0 ]; then
  echo "❌ Tests failed. Commit aborted."
  exit 1
fi

echo "✅ All tests passed!"
```

---

## 6. Implementation Timeline

| Week | Focus | Deliverables | Hours |
|------|-------|--------------|-------|
| **Week 1** | Infrastructure + auth.ts | `deno.jsonc`, `test-utils.ts`, `auth.test.ts`, CI workflow | 8-10 |
| **Week 2** | Shared utilities | `plaid.test.ts`, `recurring.test.ts` | 8-10 |
| **Week 3** | Simple functions | 3 test files for simple functions | 10-12 |
| **Week 4** | Complex functions (part 1) | `save-item.test.ts`, `sync-transactions/plaid.test.ts` | 10-12 |
| **Week 5** | Complex functions (part 2) | `sync-transactions/index.test.ts`, `sync-recurring.test.ts`, `plaid-webhook.test.ts` | 12-15 |
| **Week 6** | Coverage & polish | Reach 80% coverage, documentation, cleanup | 6-8 |

**Total Estimated Effort:** 54-67 hours over 6 weeks

---

## 7. Testing Anti-Patterns to Avoid

❌ **Don't test implementation details** - Test behavior, not internal structure
❌ **Don't over-mock** - Mock only external dependencies (Plaid, DB), not your own utilities
❌ **Don't skip edge cases** - Test error paths, not just happy paths
❌ **Don't write integration tests as unit tests** - Keep them separate
❌ **Don't commit failing tests** - Always ensure green before push
❌ **Don't test third-party libraries** - Trust that Plaid SDK, Supabase client work
❌ **Don't write brittle tests** - Tests should be resilient to minor refactoring
❌ **Don't ignore flaky tests** - Fix or remove them immediately

---

## 8. Testing Best Practices to Follow

✅ **Do test behavior, not implementation** - Focus on inputs/outputs
✅ **Do write descriptive test names** - "should return 401 when auth header is missing"
✅ **Do follow AAA pattern** - Arrange, Act, Assert
✅ **Do test error paths** - Not just happy paths
✅ **Do keep tests fast** - Mock external calls, avoid real API calls
✅ **Do make tests independent** - Each test should run in isolation
✅ **Do use test utilities** - Reuse mock factories and helpers
✅ **Do document complex test setup** - Add comments for non-obvious mocking

---

## 9. Success Criteria

### Quantitative Metrics
- ✅ All shared utilities have 85%+ coverage
- ✅ All simple functions have 80%+ coverage
- ✅ All complex functions have 75%+ coverage
- ✅ Overall codebase has 80%+ coverage
- ✅ Test suite runs in < 30 seconds locally
- ✅ Zero flaky tests (100% consistent pass/fail)

### Qualitative Metrics
- ✅ CI/CD pipeline runs tests on every PR
- ✅ Tests catch regressions before production
- ✅ Developers feel confident making changes
- ✅ Test documentation exists in README
- ✅ New functions include tests from day 1

---

## 10. Running Tests

### Local Development

```bash
# Navigate to functions directory
cd supabase/functions

# Run all tests
deno task test

# Run tests in watch mode (re-run on file changes)
deno task test:watch

# Run only unit tests (skip integration)
deno task test:unit

# Run with coverage
deno task test:coverage

# Generate coverage report
deno task coverage
```

### CI/CD

Tests run automatically on:
- Every push to `main` branch
- Every pull request
- Any changes to `supabase/functions/**`

---

## 11. Maintenance & Iteration

### Weekly Reviews
- Review coverage reports every Friday
- Identify gaps in test coverage
- Prioritize high-risk, untested code

### Monthly Retrospectives
- Assess test suite performance (speed, flakiness)
- Gather team feedback on testing experience
- Adjust testing strategy as needed

### Continuous Improvement
- Refactor tests as code evolves
- Remove obsolete tests
- Update mocks when APIs change
- Keep dependencies up to date

---

## 12. Resources & References

### Official Documentation
- [Testing your Edge Functions | Supabase Docs](https://supabase.com/docs/guides/functions/unit-test)
- [Writing tests | Deno Docs](https://docs.deno.com/examples/testing_tutorial/)
- [Testing | Deno Fundamentals](https://docs.deno.com/runtime/fundamentals/testing/)
- [Testing in isolation with mocks | Deno Docs](https://docs.deno.com/examples/mocking_tutorial/)

### Community Resources
- [Testing Supabase Edge Functions with Deno Test](https://blog.mansueli.com/testing-supabase-edge-functions-with-deno-test)
- [Unit testing of HTTP server in Deno](https://medium.com/deno-the-complete-reference/unit-testing-of-http-server-in-deno-a03b1c028f92)
- [Testing with Deno — Part 1 Basics](https://medium.com/deno-the-complete-reference/testing-with-deno-part-1-basics-375aa90c5cb5)

### Tools
- [Deno Standard Library Assertions](https://deno.land/std@0.224.0/assert/mod.ts)
- [Codecov](https://codecov.io/) - Coverage reporting
- [GitHub Actions](https://github.com/features/actions) - CI/CD

---

## 13. Next Steps

1. **✅ Review & approve this plan**
2. **Week 1: Set up infrastructure**
   - Create `deno.jsonc`
   - Create `test-utils.ts`
   - Set up GitHub Actions workflow
   - Write first test file: `auth.test.ts`
3. **Week 2-5: Implement tests**
   - Follow the priority order outlined above
   - Review coverage reports weekly
4. **Week 6: Polish & document**
   - Ensure 80% coverage
   - Add testing guide to main README
   - Document any testing gotchas

---

## Appendix A: Example Test File

Here's a complete example of what a test file should look like:

```typescript
// _shared/auth.test.ts
import {
  assertEquals,
  assertExists,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  createAuthenticatedClient,
  requireAuth,
  jsonResponse,
} from "./auth.ts";
import { createMockRequest } from "./test-utils.ts";

// Test suite for createAuthenticatedClient
Deno.test("createAuthenticatedClient: should create client with valid JWT", async () => {
  // Arrange
  const mockJWT = "Bearer valid-jwt-token";
  const request = createMockRequest({
    headers: { Authorization: mockJWT },
  });

  // Act
  const client = await createAuthenticatedClient(request);

  // Assert
  assertExists(client);
  // Additional assertions...
});

Deno.test("createAuthenticatedClient: should throw with invalid JWT", async () => {
  // Arrange
  const request = createMockRequest({
    headers: { Authorization: "Bearer invalid-token" },
  });

  // Act & Assert
  await assertRejects(
    async () => await createAuthenticatedClient(request),
    Error,
    "Invalid token"
  );
});

// Test suite for requireAuth
Deno.test("requireAuth: should return 401 for missing Authorization header", async () => {
  // Arrange
  const request = createMockRequest({ method: "GET" });

  // Act
  const response = await requireAuth(request);

  // Assert
  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.error, "Missing authorization header");
});

// Test suite for jsonResponse
Deno.test("jsonResponse: should include CORS headers", () => {
  // Arrange
  const data = { message: "success" };

  // Act
  const response = jsonResponse(data);

  // Assert
  assertEquals(response.status, 200);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
  // Additional assertions...
});
```

---

## Appendix B: Coverage Reporting

### Generating Coverage Reports

```bash
# Run tests with coverage
deno task test:coverage

# Generate LCOV report
deno task coverage

# View coverage in browser (requires lcov-viewer or similar)
# The lcov file will be at: supabase/functions/coverage.lcov
```

### Interpreting Coverage

Coverage metrics to track:
- **Line Coverage**: % of lines executed
- **Branch Coverage**: % of conditional branches tested
- **Function Coverage**: % of functions called

**Target:** 80%+ overall, with focus on critical business logic

---

## Document History

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-31 | 1.0 | Initial testing plan created |

---

**Prepared by:** Claude Code
**Last Updated:** 2026-01-31
**Status:** Draft - Awaiting Approval
