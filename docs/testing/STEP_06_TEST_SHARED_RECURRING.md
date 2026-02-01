# Step 6: Test Shared Recurring Module

**Estimated Time:** 4-6 hours
**Prerequisites:** Steps 1-5 completed
**Phase:** 2 - Shared Utilities Testing
**Target Coverage:** 90%+

---

## Overview

Test `_shared/recurring.ts` which handles recurring transaction flag updates and profile summary calculations.

---

## Implementation

Create `supabase/functions/_shared/recurring.test.ts`:

### Key Test Cases

**updateTransactionRecurringFlags:**
- Marks transactions as recurring when matched to stream
- Respects user_marked_recurring flag (doesn't override)
- Respects is_excluded flag
- Handles TOMBSTONE status
- Updates correct transactions only
- Handles empty stream list

**updateProfileRecurringSummary:**
- Calculates total monthly income correctly
- Calculates total monthly expenses correctly
- Separates inflow vs outflow streams
- Handles different frequencies (WEEKLY, MONTHLY, ANNUALLY)
- Updates profile table correctly
- Handles zero recurring items

### Example Tests

```typescript
import { setupTestEnvironment, assertEquals, createMockSupabaseClient } from "./test-utils.ts";
import { updateTransactionRecurringFlags, updateProfileRecurringSummary } from "./recurring.ts";

await setupTestEnvironment();

Deno.test("updateTransactionRecurringFlags: marks matching transactions", async () => {
  const mockClient = createMockSupabaseClient({
    mockData: {
      transactions: [
        { id: 1, name: 'Netflix', is_recurring: false },
        { id: 2, name: 'Spotify', is_recurring: false },
      ]
    }
  });

  const streams = [
    { stream_id: 's1', description: 'Netflix', status: 'ACTIVE' }
  ];

  await updateTransactionRecurringFlags(mockClient, streams, 'user-1');

  // Verify transaction 1 was marked recurring (Netflix matched)
  // Transaction 2 should remain non-recurring
});

Deno.test("updateProfileRecurringSummary: calculates totals correctly", async () => {
  const mockClient = createMockSupabaseClient({
    mockData: {
      profiles: [{ id: 'user-1', monthly_income: 0, monthly_expenses: 0 }]
    }
  });

  const inflowStreams = [
    { monthly_amount: 5000, is_active: true } // Salary
  ];

  const outflowStreams = [
    { monthly_amount: 1500, is_active: true }, // Rent
    { monthly_amount: 100, is_active: true }   // Netflix
  ];

  await updateProfileRecurringSummary(
    mockClient,
    'user-1',
    inflowStreams,
    outflowStreams
  );

  // Should update profile with income=5000, expenses=1600
});

// Additional tests for:
// - Respecting user overrides
// - Handling inactive streams
// - TOMBSTONE status filtering
// - Edge cases (null values, empty arrays)
```

---

## Validation

```bash
deno test _shared/recurring.test.ts -A --coverage=coverage
deno coverage coverage --include=_shared/recurring.ts
```

Target: 90%+ coverage

---

## Commit

```bash
git add supabase/functions/_shared/recurring.test.ts
git commit -m "Add tests for shared recurring module

- Test transaction flag updates
- Test profile summary calculations
- Test frequency conversions
- Test user override handling
- Achieve 90%+ coverage"
```

---

## Next Step

Proceed to [Step 7: Test Simple Functions](./STEP_07_TEST_SIMPLE_FUNCTIONS.md)
