# Shared Utilities for Edge Functions

This directory contains reusable utilities for Supabase Edge Functions.

---

## Files

### `auth.ts`

Authentication utilities for handling Supabase Auth in Edge Functions.

**Key Functions:**

- `createAuthenticatedClient(req)` - Creates a Supabase client with user JWT token
- `createServiceRoleClient()` - Creates a client with service role (bypasses RLS)
- `getAuthenticatedUser(req)` - Returns authenticated user or error
- `requireAuth(req)` - Middleware-style auth check (returns 401 if invalid)
- `handleCors(req)` - Handles CORS preflight requests
- `jsonResponse(data, status)` - Creates JSON response with proper headers

**When to use each client type:**

| Client Type | Use Case | RLS Behavior |
|-------------|----------|--------------|
| `createAuthenticatedClient()` | User-facing endpoints (GET items, POST transaction) | ✅ Enforced - filters by user.id |
| `createServiceRoleClient()` | Webhooks, cron jobs (no user context) | ❌ Bypassed - access all data |

## Usage

Import utilities in your Edge Function:

```typescript
import {
  requireAuth,
  handleCors,
  jsonResponse,
  createAuthenticatedClient,
} from '../_shared/auth.ts';
```

## Examples

See `supabase/functions/example-auth/index.ts` for complete examples.

### Quick Start: Authenticated Endpoint

```typescript
Deno.serve(async (req) => {
  // Handle CORS
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // Require authentication
  const authResult = await requireAuth(req);
  if (authResult instanceof Response) {
    return authResult; // 401 error
  }

  const user = authResult;
  const supabase = createAuthenticatedClient(req);

  // Query data (RLS automatically filters by user.id)
  const { data } = await supabase.from('items').select('*');

  return jsonResponse({ user, data });
});
```

### Webhook Endpoint (No User Context)

```typescript
import { createServiceRoleClient, jsonResponse } from '../_shared/auth.ts';

Deno.serve(async (req) => {
  const { item_id } = await req.json();

  // Use service role - no user context needed
  const supabase = createServiceRoleClient();

  // Access any user's data (RLS bypassed)
  const { data } = await supabase
    .from('items')
    .select('*')
    .eq('plaid_item_id', item_id)
    .single();

  // Process webhook...

  return jsonResponse({ success: true });
});
```

## Migration Notes

This utilities file replaces the legacy authentication system:

**Legacy (Node.js):**
- `server/middleware/index.js:verifyToken()` - Session token validation
- `server/controllers/sessions.js` - Session management
- `server/controllers/users.js` - User registration/login

**Supabase (Edge Functions):**
- JWT tokens (managed by Supabase Auth)
- No session table needed
- Token refresh automatic (handled by client SDK)
- RLS policies replace manual filtering

See `../../../SUPABASE.md` Phase 2 for full migration details.

---

## `plaid.ts`

Plaid API client utilities for Edge Functions.

**Key Functions:**

- `createPlaidClient()` - Creates configured Plaid API client
- `getPlaidConfig()` - Reads Plaid configuration from environment
- `handlePlaidError(error)` - Handles and formats Plaid API errors
- `validateWebhookSignature(body, signature)` - Validates Plaid webhook signatures

**Constants:**

- `PLAID_WEBHOOK_URL` - Webhook URL for Plaid (from env or default)
- `PLAID_REDIRECT_URI` - Redirect URI for Plaid Link (from env or default)

### Usage

```typescript
import { createPlaidClient, handlePlaidError } from '../_shared/plaid.ts';

const plaidClient = createPlaidClient();

try {
  const response = await plaidClient.linkTokenCreate({...});
  return jsonResponse(response.data);
} catch (error) {
  const errorResponse = handlePlaidError(error);
  return jsonResponse(errorResponse, 500);
}
```

### Environment Variables Required

Set these via Supabase CLI:

```bash
supabase secrets set PLAID_CLIENT_ID=your_client_id
supabase secrets set PLAID_SECRET=your_secret
supabase secrets set PLAID_ENV=sandbox  # or development, production
```

Optional overrides:

```bash
supabase secrets set PLAID_WEBHOOK_URL=https://your-domain.com/webhook
supabase secrets set PLAID_REDIRECT_URI=https://your-domain.com/redirect
```

### Error Handling

The `handlePlaidError()` function formats Plaid errors consistently:

**Plaid API Error:**
```json
{
  "error": "Plaid API error",
  "details": {
    "error_code": "INVALID_ACCESS_TOKEN",
    "error_message": "...",
    "request_id": "..."
  }
}
```

**Network Error:**
```json
{
  "error": "Failed to connect to Plaid",
  "details": {
    "code": "ETIMEDOUT",
    "message": "Connection timeout"
  }
}
```

**Generic Error:**
```json
{
  "error": "Failed to process Plaid request",
  "details": "Error message here"
}
```

---

## Adding New Utilities

When adding new shared utilities:

1. **Create the file** in `_shared/` directory
2. **Export functions** that will be reused across Edge Functions
3. **Add documentation** to this README
4. **Include usage examples**
5. **Update related Edge Functions** to use the new utilities

### Example Structure

```typescript
// _shared/my-utility.ts

/**
 * Description of what this utility does
 */

export function myUtilityFunction(param: string): string {
  // Implementation
  return result;
}

export const MY_CONSTANT = 'value';
```

---

## Best Practices

### 1. Keep Utilities Focused

Each utility file should have a single responsibility:
- `auth.ts` - Authentication only
- `plaid.ts` - Plaid API only
- Future: `database.ts` - Database helpers only

### 2. Use TypeScript

All utilities should be TypeScript for type safety:
- Define interfaces for complex types
- Use proper return types
- Export types that consumers need

### 3. Handle Errors Gracefully

Utilities should:
- Never throw unhandled errors
- Return error objects or throw typed errors
- Log errors appropriately

### 4. Document Everything

Each utility should have:
- File-level JSDoc comment
- Function-level JSDoc comments
- Usage examples
- Parameter descriptions
- Return value descriptions

### 5. Test Utilities

When possible, utilities should be testable:
- Avoid side effects
- Accept dependencies as parameters
- Return predictable values

---

## Migration Notes

These utilities replace legacy backend code:

| Legacy | Supabase (_shared) |
|--------|-------------------|
| `server/middleware/index.js:verifyToken()` | `auth.ts:requireAuth()` |
| `server/plaid/loggingPlaidClient.js` | `plaid.ts:createPlaidClient()` |
| Session token validation | JWT validation (automatic) |
| Manual user filtering | RLS (automatic) |

See `../../../SUPABASE.md` for full migration details.
