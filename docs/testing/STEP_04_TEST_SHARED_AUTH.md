# Step 4: Test Shared Auth Module

**Estimated Time:** 6-8 hours
**Prerequisites:** Steps 1-3 completed
**Phase:** 2 - Shared Utilities Testing
**Target Coverage:** 90%+

---

## Overview

Create comprehensive tests for `_shared/auth.ts`, which handles authentication, CORS, and JWT validation for all edge functions.

---

## Implementation

Create `supabase/functions/_shared/auth.test.ts` with tests covering all auth utilities. This file should test:

1. **createAuthenticatedClient()** - Creates Supabase client from JWT
2. **createServiceRoleClient()** - Creates admin client
3. **getAuthenticatedUser()** - Extracts user from request
4. **requireAuth()** - Returns 401 if auth missing
5. **handleCors()** - Returns preflight response
6. **jsonResponse()** - Adds CORS headers
7. **Environment variable handling** - CUSTOM_ prefix fallback

### Test Structure

```typescript
import { setupTestEnvironment, assertEquals, assertExists, assertRejects, createMockRequest, createTestJWT } from "./test-utils.ts";
import { requireAuth, handleCors, jsonResponse, getAuthenticatedUser } from "./auth.ts";

// Load environment before tests
await setupTestEnvironment();

// Test: requireAuth with valid JWT
Deno.test("requireAuth: returns user when valid JWT provided", async () => {
  const jwt = await createTestJWT({ userId: 'test-user' });
  const request = createMockRequest({
    headers: { Authorization: jwt }
  });

  const result = await requireAuth(request);

  // Should NOT return a Response (only returns Response on error)
  assertEquals(result instanceof Response, false);
});

// Test: requireAuth without JWT
Deno.test("requireAuth: returns 401 when Authorization header missing", async () => {
  const request = createMockRequest({ method: 'GET' });

  const response = await requireAuth(request);

  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.error, 'Missing authorization header');
});

// Test: CORS preflight
Deno.test("handleCors: returns 200 for OPTIONS request", () => {
  const response = handleCors();

  assertEquals(response.status, 200);
  assertEquals(response.headers.get('Access-Control-Allow-Origin'), '*');
  assertExists(response.headers.get('Access-Control-Allow-Methods'));
});

// Test: jsonResponse includes CORS headers
Deno.test("jsonResponse: includes CORS headers", () => {
  const data = { message: 'success' };
  const response = jsonResponse(data);

  assertEquals(response.status, 200);
  assertEquals(response.headers.get('Access-Control-Allow-Origin'), '*');
  assertEquals(response.headers.get('Content-Type'), 'application/json');
});

// Additional tests for:
// - Invalid JWT format
// - Expired JWT
// - getAuthenticatedUser with valid/invalid token
// - createServiceRoleClient initialization
// - Environment variable fallback (CUSTOM_ prefix)
// - Error responses with different status codes
```

### Key Test Cases

**Authentication:**
- Valid JWT → successful client creation
- Invalid JWT → error thrown
- Missing JWT → 401 response
- Expired JWT → error handled
- Malformed Authorization header → error

**CORS:**
- OPTIONS request → 200 with CORS headers
- jsonResponse → includes CORS headers
- All HTTP methods allowed

**Environment:**
- Uses SUPABASE_URL if available
- Falls back to CUSTOM_SUPABASE_URL
- Throws error if neither available

---

## Validation

Run the tests:

```bash
cd supabase/functions
deno test _shared/auth.test.ts -A
```

Check coverage:

```bash
deno test _shared/auth.test.ts -A --coverage=coverage
deno coverage coverage --include=_shared/auth.ts
```

Target: 90%+ coverage

---

## Commit

```bash
git add supabase/functions/_shared/auth.test.ts
git commit -m "Add comprehensive tests for shared auth module

- Test JWT authentication flow
- Test CORS handling
- Test error responses
- Test environment variable fallback
- Achieve 90%+ coverage"
```

---

## Next Step

Proceed to [Step 5: Test Shared Plaid Module](./STEP_05_TEST_SHARED_PLAID.md)
