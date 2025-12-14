# Phase 2 Migration Summary: Authentication Replacement

**Date**: December 11, 2025
**Status**: Server-side changes complete ✅
**Next Steps**: iOS client updates (see below)

---

## What Was Done

### 1. Legacy Authentication Code Archived

The following files were moved to `server/archived/phase2-auth-migration/`:

- ✅ `server/controllers/users.js` - User registration, login, password hashing
- ✅ `server/controllers/sessions.js` - Session token generation and validation
- ✅ `server/routes/auth.js` - `/register` and `/login` endpoints

**Why archived, not deleted?**
- Preserves git history for reference
- Allows rollback if needed during migration
- Can be referenced when porting logic to Edge Functions

### 2. Legacy Middleware Documented as Deprecated

The `verifyToken` middleware in `server/middleware/index.js` has been marked as deprecated with documentation explaining:
- It's part of the legacy authentication system
- Will be removed after full migration to Supabase
- How auth works in Supabase Edge Functions (JWT + RLS)

**Note**: The middleware remains functional for now to support any remaining legacy routes during the migration.

### 3. Supabase Auth Utilities Created

New authentication utilities for Edge Functions:

**File**: `supabase/functions/_shared/auth.ts`

Key exports:
- `createAuthenticatedClient(req)` - Create Supabase client with user JWT
- `createServiceRoleClient()` - Create client for webhooks (bypasses RLS)
- `requireAuth(req)` - Verify authentication and return user or 401
- `handleCors(req)` - Handle CORS preflight requests
- `jsonResponse(data, status)` - Create JSON responses with proper headers

### 4. Example Edge Function Created

**File**: `supabase/functions/example-auth/index.ts`

Demonstrates:
- ✅ How to require authentication
- ✅ How to parse request bodies
- ✅ How to handle CORS
- ✅ How to query data with RLS
- ✅ Error handling patterns
- ✅ Complete usage examples with curl and Swift

**Purpose**: Reference implementation for Phase 3 when creating production Edge Functions.

---

## Key Differences: Legacy vs Supabase Auth

| Aspect | Legacy (Node.js) | Supabase (Edge Functions) |
|--------|------------------|---------------------------|
| **Token Type** | Random 128-char hex string | JWT (signed by Supabase) |
| **Token Storage** | `sessions_table` in database | No database storage needed |
| **Token Validation** | Database lookup on every request | JWT signature verification (fast!) |
| **User Retrieval** | Join `sessions` → `users` tables | Decode JWT payload |
| **Auth Middleware** | `verifyToken()` middleware | `requireAuth()` utility function |
| **Session Expiry** | Manual expiration logic | Automatic via JWT exp claim |
| **Token Refresh** | Manual implementation needed | Built into Supabase Auth SDK |
| **Data Filtering** | Manual `WHERE user_id = $1` | Automatic via RLS policies |

---

## Next Steps

### For Backend/Edge Functions (Phase 3)

When creating new Edge Functions, follow this pattern:

```typescript
import { requireAuth, handleCors, jsonResponse, createAuthenticatedClient } from '../_shared/auth.ts';

Deno.serve(async (req) => {
  // 1. Handle CORS
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // 2. Require authentication
  const authResult = await requireAuth(req);
  if (authResult instanceof Response) return authResult;

  const user = authResult;
  const supabase = createAuthenticatedClient(req);

  // 3. Your business logic here
  const { data } = await supabase.from('table').select('*');

  // 4. Return JSON response
  return jsonResponse({ data });
});
```

**Edge Functions to create in Phase 3**:
- [ ] `plaid-link-token` - Generate Plaid Link tokens (from `server/routes/linkTokens.js`)
- [ ] `plaid-webhook` - Handle Plaid webhooks (from `server/routes/webhook.js`)
- [ ] `sync-transactions` - Sync transactions from Plaid (from `server/controllers/transactions.js`)

See `SUPABASE.md` Phase 3 for detailed instructions.

### For iOS Client

The iOS app needs to be updated to use Supabase Auth instead of custom auth:

**Current (Legacy):**
```swift
// POST to /auth/register or /auth/login
// Store session token in Keychain
// Include token in Authorization header
```

**New (Supabase):**
```swift
import Supabase

// 1. Initialize Supabase client (in AppDelegate or similar)
let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://[project].supabase.co")!,
  supabaseKey: "[anon-key]"
)

// 2. Sign up
try await supabase.auth.signUp(email: email, password: password)

// 3. Sign in
let session = try await supabase.auth.signIn(email: email, password: password)
// session.accessToken is the JWT - automatically included in all requests

// 4. No manual token storage needed - SDK handles it!
```

**Files to update**:
- [ ] `ios/Bablo/Managers/AuthManager.swift` - Replace with Supabase Auth
- [ ] `ios/Bablo/ViewModels/LoginViewModel.swift` - Use new auth methods
- [ ] `ios/Bablo/ViewModels/RegisterViewModel.swift` - Use new auth methods
- [ ] `ios/Bablo/Services/APIClient.swift` - Update to use Supabase client

**iOS Configuration Setup**:

The iOS app uses a **build-time script** to generate configuration from Build Settings:

1. **Build Settings** store credentials:
   - `SUPABASE_URL` - Project URL or local dev URL
   - `SUPABASE_ANON_KEY` - Anonymous/public API key

2. **Build Phase Script** auto-generates `Util/Config.swift`:
   ```bash
   # Generates Config.swift from build settings
   CONFIG_FILE="${SRCROOT}/Bablo/Util/Config.swift"
   cat > "$CONFIG_FILE" << EOF
     enum Config {
         static let supabaseURL = "${SUPABASE_URL}"
         static let supabaseAnonKey = "${SUPABASE_ANON_KEY}"
     }
   EOF
   ```

3. **SupabaseManager** reads from generated config:
   ```swift
   let supabaseURL = Config.supabaseURL
   let supabaseAnonKey = Config.supabaseAnonKey
   self.client = SupabaseClient(supabaseURL: url, supabaseKey: supabaseAnonKey)
   ```

**Benefits**:
- ✅ Credentials never committed to source control
- ✅ Easy to switch between local dev and production
- ✅ Different configs per build configuration (Debug/Release)
- ✅ No manual file editing needed

**Resources**:
- [Supabase Swift SDK Docs](https://supabase.com/docs/reference/swift/introduction)
- [Auth Examples](https://supabase.com/docs/guides/auth/auth-helpers/ios)
- See `IOS_APPLE_SIGNIN_SETUP.md` for detailed setup instructions

---

## Testing Guide

### Test Edge Function Locally

1. Start Supabase locally:
   ```bash
   cd supabase
   supabase start
   ```

2. Serve the example function:
   ```bash
   supabase functions serve example-auth
   ```

3. Create a test user:
   ```bash
   curl -X POST 'http://localhost:54321/auth/v1/signup' \
     -H "apikey: [anon-key-from-supabase-start]" \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com","password":"password123"}'
   ```

4. Get access token:
   ```bash
   curl -X POST 'http://localhost:54321/auth/v1/token?grant_type=password' \
     -H "apikey: [anon-key]" \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com","password":"password123"}'
   ```

5. Call the function:
   ```bash
   curl 'http://localhost:54321/functions/v1/example-auth' \
     -H "Authorization: Bearer [access-token-from-step-4]" \
     -H "Content-Type: application/json"
   ```

### Deploy to Production

```bash
cd supabase

# Deploy function
supabase functions deploy example-auth

# Set environment secrets (if needed)
supabase secrets set PLAID_CLIENT_ID=your-id
supabase secrets set PLAID_SECRET=your-secret
```

---

## Rollback Plan

If issues arise during migration:

1. **Revert archived files**:
   ```bash
   git mv server/archived/phase2-auth-migration/*.js server/controllers/
   git mv server/archived/phase2-auth-migration/auth.js server/routes/
   ```

2. **Remove deprecation notice** from `server/middleware/index.js`

3. **Keep Supabase setup** - it can coexist with legacy auth

4. **Gradually migrate** - no need to do everything at once

---

## Security Notes

### ⚠️ Important: Service Role Key

The `SUPABASE_SERVICE_ROLE_KEY` bypasses Row Level Security (RLS).

**Use ONLY for**:
- Webhook functions (no user context)
- Cron jobs
- Admin operations

**NEVER use for**:
- User-facing endpoints
- Any function that should respect RLS

**Example of proper use**:
```typescript
// ✅ CORRECT - webhook has no user context
// supabase/functions/plaid-webhook/index.ts
const supabase = createServiceRoleClient(); // OK - webhook

// ❌ WRONG - user endpoint should use auth client
// supabase/functions/get-user-items/index.ts
const supabase = createServiceRoleClient(); // BAD - bypasses RLS!
```

### JWT Token Security

Supabase Auth JWTs are:
- Short-lived (1 hour by default)
- Automatically refreshed by client SDK
- Signed with HMAC-SHA256
- Cannot be forged (validated by signature)

No need to store tokens in database like the legacy system.

---

## Questions & Troubleshooting

### "Unauthorized" errors in Edge Functions

**Check**:
1. Is the Authorization header being sent? (`req.headers.get('Authorization')`)
2. Is the token format correct? (`Bearer <jwt>`)
3. Is the token expired? (JWT exp claim)
4. Are RLS policies correctly configured?

**Debug**:
```typescript
const authHeader = req.headers.get('Authorization');
console.log('Auth header:', authHeader); // Should be "Bearer eyJ..."

const { data: { user }, error } = await supabase.auth.getUser();
console.log('User:', user, 'Error:', error);
```

### "Missing Authorization header" error

The client needs to include the JWT token:

**Swift**:
```swift
// Supabase SDK does this automatically
let response = try await supabase.functions.invoke("function-name")
```

**Curl**:
```bash
curl -H "Authorization: Bearer [token]" ...
```

### Legacy routes still work after archiving

The archived controllers are no longer imported, but:
- The `verifyToken` middleware still exists
- Other routes may still be active
- The legacy Express server is still running

This is intentional - allows gradual migration.

---

## References

- **Main Migration Plan**: `SUPABASE.md`
- **Auth Utilities**: `supabase/functions/_shared/auth.ts`
- **Example Function**: `supabase/functions/example-auth/index.ts`
- **Supabase Docs**: https://supabase.com/docs/guides/auth
- **RLS Guide**: https://supabase.com/docs/guides/auth/row-level-security

---

## Summary

✅ **Completed**:
- Legacy auth code archived
- Auth utilities created
- Example Edge Function created
- Documentation written

⏳ **Remaining**:
- Update iOS app to use Supabase Auth SDK
- Create production Edge Functions (Phase 3)
- Test end-to-end auth flow
- Remove legacy middleware after full migration

**Next Phase**: Phase 3 - Create Edge Functions for core business logic (Plaid integration, transactions sync, etc.)
