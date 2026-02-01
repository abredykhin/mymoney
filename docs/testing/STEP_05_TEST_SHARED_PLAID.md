# Step 5: Test Shared Plaid Module

**Estimated Time:** 6-8 hours
**Prerequisites:** Steps 1-4 completed
**Phase:** 2 - Shared Utilities Testing
**Target Coverage:** 85%+

---

## Overview

Test `_shared/plaid.ts` which handles Plaid client configuration, error handling, and webhook signature validation.

---

## Implementation

Create `supabase/functions/_shared/plaid.test.ts`:

### Key Test Cases

**Configuration:**
- `getPlaidConfig()` reads environment correctly
- Throws error when PLAID_CLIENT_ID missing
- Throws error when PLAID_SECRET missing
- Handles different PLAID_ENV values (sandbox, development, production)

**Client Creation:**
- `createPlaidClient()` returns configured client
- Client has correct environment setting
- Client has correct credentials

**Error Handling:**
- `handlePlaidError()` formats ITEM_LOGIN_REQUIRED
- `handlePlaidError()` formats RATE_LIMIT errors
- `handlePlaidError()` formats generic errors
- Returns appropriate HTTP status codes

**Webhook Validation:**
- `validateWebhookSignature()` accepts valid signature
- Rejects expired webhook (>5 minutes old)
- Rejects invalid signature
- Rejects tampered body
- Works with different payload types

### Example Tests

```typescript
import { setupTestEnvironment, assertEquals, assertExists, assertRejects, createMockWebhookSignature } from "./test-utils.ts";
import { getPlaidConfig, createPlaidClient, handlePlaidError, validateWebhookSignature } from "./plaid.ts";

await setupTestEnvironment();

Deno.test("getPlaidConfig: reads environment variables correctly", () => {
  const config = getPlaidConfig();

  assertExists(config.clientId);
  assertExists(config.secret);
  assertExists(config.env);
});

Deno.test("validateWebhookSignature: accepts valid signature", async () => {
  const payload = {
    webhook_type: 'TRANSACTIONS',
    webhook_code: 'DEFAULT_UPDATE',
    item_id: 'test-item'
  };

  const { signature, body } = await createMockWebhookSignature({ payload });

  const isValid = await validateWebhookSignature(signature, body);
  assertEquals(isValid, true);
});

Deno.test("validateWebhookSignature: rejects expired webhook", async () => {
  const payload = { webhook_type: 'TRANSACTIONS' };
  const { signature, body } = await createMockWebhookSignature({
    payload,
    expired: true
  });

  const isValid = await validateWebhookSignature(signature, body);
  assertEquals(isValid, false);
});

// Additional tests for:
// - Invalid signature rejection
// - Body tampering detection
// - Error formatting with different Plaid error types
// - Rate limit error handling
// - ITEM_LOGIN_REQUIRED handling
```

---

## Validation

```bash
deno test _shared/plaid.test.ts -A --coverage=coverage
deno coverage coverage --include=_shared/plaid.ts
```

Target: 85%+ coverage

---

## Commit

```bash
git add supabase/functions/_shared/plaid.test.ts
git commit -m "Add tests for shared Plaid module

- Test Plaid client configuration
- Test webhook signature validation
- Test error handling and formatting
- Test security features (expiry, tampering)
- Achieve 85%+ coverage"
```

---

## Next Step

Proceed to [Step 6: Test Shared Recurring Module](./STEP_06_TEST_SHARED_RECURRING.md)
