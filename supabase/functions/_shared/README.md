# Shared Utilities for Edge Functions

This directory contains reusable utilities for Supabase Edge Functions.

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
