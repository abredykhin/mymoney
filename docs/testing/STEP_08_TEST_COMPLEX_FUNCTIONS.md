# Step 8: Test Complex Functions

**Estimated Time:** 20-25 hours
**Prerequisites:** Steps 1-7 completed
**Phase:** 4 - Complex Functions
**Target Coverage:** 75%+ each

---

## Overview

Create tests for the most complex edge functions with significant business logic:
1. `save-item/index.ts` - Full account linking flow
2. `sync-transactions/plaid.ts` - Plaid API interaction layer
3. `sync-transactions/index.ts` - Main transaction sync logic
4. `sync-recurring-transactions/index.ts` - Recurring transaction sync
5. `plaid-webhook/index.ts` - Webhook handler

**Note:** The existing `sync-transactions/database.test.ts` (15 tests) already provides good coverage for database operations. This step complements that with additional tests.

---

## Implementation

### 8.1: Test save-item

Create `supabase/functions/save-item/index.test.ts`:

**Key Test Cases:**
- Full flow: public_token → access_token → save item
- Duplicate item detection (same item_id)
- Institution upsert logic (create or update)
- Account creation for new item
- Initial sync trigger (fire-and-forget)
- Error handling at each step:
  - Token exchange fails
  - Institution fetch fails
  - Accounts fetch fails
  - Database save fails
- RLS compliance (user_id filtering)

### 8.2: Test sync-transactions/plaid.ts

Create `supabase/functions/sync-transactions/plaid.test.ts`:

**Key Test Cases:**
- `fetchTransactionUpdates()` handles pagination
- Handles has_more=true correctly
- Rate limit handling (429 errors)
- Exponential backoff logic
- `fetchAccountBalances()` returns correct data
- Error handling:
  - ITEM_LOGIN_REQUIRED
  - RATE_LIMIT
  - Network timeouts

**Use FakeTime for testing retries:**
```typescript
import { FakeTime } from "../_shared/test-utils.ts";

Deno.test("fetchTransactionUpdates: retries on rate limit", async () => {
  const time = new FakeTime();

  try {
    let attemptCount = 0;
    const mockPlaid = {
      transactionsSync: async () => {
        attemptCount++;
        if (attemptCount < 3) {
          throw new Error("RATE_LIMIT");
        }
        return { data: { added: [], modified: [], removed: [] } };
      }
    };

    const promise = fetchTransactionUpdates(mockPlaid, "access-token");

    await time.tickAsync(1000);  // First retry
    await time.tickAsync(2000);  // Second retry

    const result = await promise;
    assertEquals(attemptCount, 3);
  } finally {
    time.restore();
  }
});
```

### 8.3: Test sync-transactions/index.ts

Create `supabase/functions/sync-transactions/index.test.ts`:

**Key Test Cases:**
- Full sync flow with pagination
- Cursor management (only updated on success)
- Account ID mapping (Plaid ID → internal ID)
- Batch operations execution order:
  1. Insert new transactions
  2. Update modified transactions
  3. Delete removed transactions
  4. Update balances
- Historical sync completion detection
- Recurring sync trigger conditions
- Error recovery (cursor not updated on failure)

### 8.4: Test sync-recurring-transactions

Create `supabase/functions/sync-recurring-transactions/index.test.ts`:

**Key Test Cases:**
- Processes inflow and outflow streams separately
- Frequency conversion logic:
  - WEEKLY → monthly_amount * 4.33
  - MONTHLY → monthly_amount
  - ANNUALLY → monthly_amount / 12
- Preserves user overrides:
  - user_marked_recurring
  - is_excluded
- Manual stream pattern matching
- Transaction linking to streams
- Profile summary update
- Handles inactive/tombstone streams

### 8.5: Test plaid-webhook

Create `supabase/functions/plaid-webhook/index.test.ts`:

**Key Test Cases:**
- Webhook signature verification (critical security test)
- TRANSACTIONS webhooks trigger sync
- RECURRING_TRANSACTIONS_UPDATE trigger
- ITEM error handling (ITEM_LOGIN_REQUIRED)
- Returns 200 for invalid payloads (prevent retries)
- Returns 401 for invalid signatures
- Background processing (ctx.waitUntil)
- Local dev mode bypasses verification
- Different webhook types:
  - DEFAULT_UPDATE
  - INITIAL_UPDATE
  - HISTORICAL_UPDATE
  - TRANSACTIONS_REMOVED

---

## Testing Strategy for Complex Functions

**Challenge:** These functions are large and have many dependencies.

**Solutions:**

1. **Extract testable logic:**
   ```typescript
   // Before (hard to test):
   export default async function handler(req: Request) {
     const data = await req.json();
     const result = complexLogic(data);
     return new Response(JSON.stringify(result));
   }

   // After (easy to test):
   export function complexLogic(data: any) {
     // Pure function, easy to test
     return processedData;
   }

   export default async function handler(req: Request) {
     const data = await req.json();
     const result = complexLogic(data);
     return new Response(JSON.stringify(result));
   }
   ```

2. **Test business logic separately from HTTP handling:**
   - Focus tests on core algorithms
   - Mock HTTP request/response in handler tests
   - Use integration tests sparingly for end-to-end validation

3. **Use realistic mock data:**
   - Create fixtures for common scenarios
   - Include edge cases in fixtures
   - Test with production-like data volumes

---

## Validation

```bash
# Test each function individually
deno test save-item/index.test.ts -A
deno test sync-transactions/plaid.test.ts -A
deno test sync-transactions/index.test.ts -A
deno test sync-recurring-transactions/index.test.ts -A
deno test plaid-webhook/index.test.ts -A

# Run all tests
deno task test

# Check overall coverage
deno task test:coverage
deno task coverage
```

Target: 75%+ coverage for each complex function

---

## Commit

```bash
git add supabase/functions/save-item/index.test.ts
git add supabase/functions/sync-transactions/plaid.test.ts
git add supabase/functions/sync-transactions/index.test.ts
git add supabase/functions/sync-recurring-transactions/index.test.ts
git add supabase/functions/plaid-webhook/index.test.ts

git commit -m "Add comprehensive tests for complex edge functions

- Test save-item account linking flow
- Test sync-transactions with pagination and retry logic
- Test sync-recurring-transactions processing
- Test plaid-webhook handling and security
- Achieve 75%+ coverage for complex functions"
```

---

## Next Step

Proceed to [Step 9: Setup CI/CD Pipeline](./STEP_09_SETUP_CI_CD.md)
