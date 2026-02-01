# Step 7: Test Simple Functions

**Estimated Time:** 10-12 hours
**Prerequisites:** Steps 1-6 completed
**Phase:** 3 - Simple Functions
**Target Coverage:** 80%+ each

---

## Overview

Create tests for three simpler edge functions:
1. `plaid-link-token/index.ts` - Generates Plaid Link tokens
2. `create-manual-stream/index.ts` - Creates manual recurring streams
3. `update-webhooks/index.ts` - Updates webhook URLs for all items

---

## Implementation

### 7.1: Test plaid-link-token

Create `supabase/functions/plaid-link-token/index.test.ts`:

**Key Test Cases:**
- New link mode: generates token with correct config
- Update mode: includes access_token for existing item
- Authentication required (returns 401 without JWT)
- Local dev mode bypasses auth
- Missing itemId in update mode returns error
- Plaid error handling
- Returns correct response format

```typescript
import { setupTestEnvironment, assertEquals, createMockRequest, createTestJWT, createMockSupabaseClient, createMockPlaidClient } from "../_shared/test-utils.ts";

await setupTestEnvironment();

Deno.test("plaid-link-token: generates token for new link", async () => {
  const jwt = await createTestJWT();
  const request = createMockRequest({
    method: 'POST',
    headers: { Authorization: jwt },
    body: { mode: 'new' }
  });

  // Mock dependencies
  const mockSupabase = createMockSupabaseClient({ mockData: {} });
  const mockPlaid = createMockPlaidClient({
    linkTokenCreate: { link_token: 'link-test-token', expiration: '2026-02-01' }
  });

  // Test the function (you'll need to refactor to inject dependencies)
  // Or use integration test approach with real mocks
});

// Additional tests for update mode, errors, auth, etc.
```

### 7.2: Test create-manual-stream

Create `supabase/functions/create-manual-stream/index.test.ts`:

**Key Test Cases:**
- Creates stream from transaction
- Pattern extraction logic
- Duplicate stream detection
- Matches related transactions
- Updates profile summary
- Frequency conversion (WEEKLY → monthly amount)

### 7.3: Test update-webhooks

Create `supabase/functions/update-webhooks/index.test.ts`:

**Key Test Cases:**
- Updates all active items
- Requires service role auth
- Returns summary with success/failure counts
- Handles Plaid API errors gracefully
- Skips inactive items

---

## Testing Pattern

For these function tests, you have two approaches:

**Approach A: Refactor for Dependency Injection**
- Extract core logic to testable functions
- Inject Supabase/Plaid clients as parameters
- Test the logic functions directly

**Approach B: Integration-Style Tests**
- Mock the global dependencies
- Test the main handler function
- More complex but tests the actual deployed code

**Recommendation:** Use Approach A for new code, Approach B for existing code to avoid major refactoring.

---

## Validation

```bash
# Test each function
deno test plaid-link-token/index.test.ts -A
deno test create-manual-stream/index.test.ts -A
deno test update-webhooks/index.test.ts -A

# Check coverage
deno test plaid-link-token/index.test.ts -A --coverage=coverage
deno coverage coverage --include=plaid-link-token/index.ts
```

Target: 80%+ coverage for each

---

## Commit

```bash
git add supabase/functions/plaid-link-token/index.test.ts
git add supabase/functions/create-manual-stream/index.test.ts
git add supabase/functions/update-webhooks/index.test.ts

git commit -m "Add tests for simple edge functions

- Test plaid-link-token token generation
- Test create-manual-stream flow
- Test update-webhooks batch updates
- Achieve 80%+ coverage for each function"
```

---

## Next Step

Proceed to [Step 8: Test Complex Functions](./STEP_08_TEST_COMPLEX_FUNCTIONS.md)
