# Supabase Edge Functions Deployment Guide

**Phase 3: Server Migration**
**Date**: December 12, 2025

This guide covers deploying and testing Supabase Edge Functions for the MyMoney (Bablo) app.

---

## 📋 Prerequisites

### 1. Supabase CLI Installed

```bash
# Check if installed
supabase --version

# If not installed (macOS):
brew install supabase/tap/supabase

# Or using npm:
npm install -g supabase
```

### 2. Supabase Project Created

- Go to https://supabase.com/dashboard
- Create a new project or use existing one
- Note your **Project ID** (from project settings)

### 3. Login to Supabase CLI

```bash
supabase login
```

---

## 🚀 Deploying Edge Functions

### Step 1: Link Your Local Project to Supabase

```bash
cd supabase
supabase link --project-ref <your-project-id>
```

Find your project ID:
- Supabase Dashboard → Settings → General → Reference ID

### Step 2: Set Environment Secrets

Edge Functions need these secrets configured:

```bash
# Plaid credentials
supabase secrets set PLAID_CLIENT_ID=your_plaid_client_id
supabase secrets set PLAID_SECRET=your_plaid_secret
supabase secrets set PLAID_ENV=sandbox  # or development, production

# Optional: Custom webhook/redirect URLs
supabase secrets set PLAID_WEBHOOK_URL=https://your-project.supabase.co/functions/v1/plaid-webhook
supabase secrets set PLAID_REDIRECT_URI=https://yourdomain.com/plaid/redirect
```

**Where to find Plaid credentials:**
- Go to https://dashboard.plaid.com
- Navigate to Team Settings → Keys
- Copy Client ID and Secret for your environment

### Step 3: Deploy Edge Function

Deploy the plaid-link-token function:

```bash
cd supabase
supabase functions deploy plaid-link-token
```

**Expected output:**
```
Deploying plaid-link-token (project ref: xyzproject)...
✓ Deployed successfully
Function URL: https://xyzproject.supabase.co/functions/v1/plaid-link-token
```

### Step 4: Verify Deployment

Check deployment status:

```bash
supabase functions list
```

You should see:
```
┌──────────────────┬─────────────────┬─────────┬─────────────────┐
│ NAME             │ SLUG            │ STATUS  │ CREATED AT      │
├──────────────────┼─────────────────┼─────────┼─────────────────┤
│ plaid-link-token │ plaid-link-token│ ACTIVE  │ 2025-12-12      │
└──────────────────┴─────────────────┴─────────┴─────────────────┘
```

---

## 🧪 Testing Edge Functions

### Local Testing (Recommended for Development)

#### Step 1: Start Supabase Locally

```bash
cd supabase
supabase start
```

This will start:
- PostgreSQL database
- Supabase Studio (http://localhost:54323)
- Edge Functions runtime

**Note the output** - you'll need:
- `anon key` - for authenticated requests
- `service_role key` - for admin requests (use carefully!)

#### Step 2: Serve Functions Locally

```bash
supabase functions serve plaid-link-token
```

Or serve all functions:

```bash
supabase functions serve
```

#### Step 3: Test with curl

First, get an access token:

```bash
# Sign in to get JWT token
curl -X POST 'http://localhost:54321/auth/v1/token?grant_type=password' \
  -H "apikey: <anon-key-from-start>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

Copy the `access_token` from response, then test the function:

```bash
# Create link token (new link mode)
curl -X POST 'http://localhost:54321/functions/v1/plaid-link-token' \
  -H "Authorization: Bearer <access-token>" \
  -H "Content-Type: application/json" \
  -d '{}'

# Create link token (update mode)
curl -X POST 'http://localhost:54321/functions/v1/plaid-link-token' \
  -H "Authorization: Bearer <access-token>" \
  -H "Content-Type: application/json" \
  -d '{"itemId": 123}'
```

**Expected response:**
```json
{
  "link_token": "link-sandbox-...",
  "expiration": "2025-12-12T12:00:00Z",
  "request_id": "..."
}
```

### Production Testing

After deploying, test the production endpoint:

```bash
# Get production JWT token (via iOS app or Supabase dashboard)
# Then test:
curl -X POST 'https://<project-id>.supabase.co/functions/v1/plaid-link-token' \
  -H "Authorization: Bearer <production-access-token>" \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## 📊 Monitoring and Debugging

### View Function Logs

**In Supabase Dashboard:**
1. Go to Edge Functions → plaid-link-token
2. Click "Logs" tab
3. See real-time logs

**Via CLI:**
```bash
supabase functions logs plaid-link-token

# Follow logs in real-time
supabase functions logs plaid-link-token --follow
```

### Common Log Messages

**Success:**
```
Creating Plaid Link token for user: 123e4567-e89b-12d3-a456-426614174000
New link mode - creating fresh link token
Requesting link token from Plaid...
Successfully created link token
```

**Errors:**
```
Error creating link token: Error: Failed to retrieve item: ...
Plaid API error: { error_code: 'INVALID_ACCESS_TOKEN', ... }
```

### Debugging Tips

1. **Check environment variables:**
   ```bash
   # List all secrets (values are hidden)
   supabase secrets list
   ```

2. **Verify authentication:**
   - Check JWT token is valid and not expired
   - Verify user exists in Supabase Auth

3. **Test Plaid connection:**
   - Verify Plaid credentials are correct
   - Check Plaid environment (sandbox vs production)
   - Review Plaid dashboard for API errors

4. **Check database permissions:**
   - Verify RLS policies allow user to read items
   - Check items table exists and has correct schema

---

## 🔄 Updating Edge Functions

After making code changes:

```bash
# Deploy updated function
cd supabase
supabase functions deploy plaid-link-token

# Or deploy all functions
supabase functions deploy
```

**Note**: Deployments are instant - no downtime!

---

## 🔐 Security Best Practices

### 1. Never Commit Secrets

✅ **DO:**
- Use `supabase secrets set` for all sensitive data
- Keep secrets in environment variables
- Use different secrets for sandbox/production

❌ **DON'T:**
- Hardcode API keys in code
- Commit `.env` files with real credentials
- Share secrets in chat/email

### 2. Validate All Inputs

The Edge Function validates:
- ✅ User is authenticated (JWT token)
- ✅ Request method is POST
- ✅ Item ID exists and belongs to user (via RLS)

### 3. Use Appropriate Keys

- **anon key**: For client-side requests (iOS app)
- **service_role key**: Only for admin/webhook functions

---

## 📱 iOS Integration

Update your iOS app to call the new Edge Function:

```swift
import Supabase

// Initialize Supabase client (if not already done)
let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://[project].supabase.co")!,
  supabaseKey: "[anon-key]"
)

// Create link token (new link mode)
func createPlaidLinkToken() async throws -> String {
    let response = try await supabase.functions.invoke(
        "plaid-link-token",
        options: FunctionInvokeOptions(
            method: .post,
            body: [:]  // Empty body for new link
        )
    )

    let data = try JSONDecoder().decode(PlaidLinkTokenResponse.self, from: response.data)
    return data.link_token
}

// Update existing item (update mode)
func updatePlaidLinkToken(itemId: Int) async throws -> String {
    let response = try await supabase.functions.invoke(
        "plaid-link-token",
        options: FunctionInvokeOptions(
            method: .post,
            body: ["itemId": itemId]
        )
    )

    let data = try JSONDecoder().decode(PlaidLinkTokenResponse.self, from: response.data)
    return data.link_token
}

struct PlaidLinkTokenResponse: Codable {
    let link_token: String
    let expiration: String
    let request_id: String
}
```

---

## 🎯 Migration Checklist

When migrating a route to Edge Functions:

- [ ] **Read legacy implementation** - Understand current behavior
- [ ] **Create Edge Function** - Port logic to Deno/TypeScript
- [ ] **Add authentication** - Use `requireAuth()` helper
- [ ] **Set environment secrets** - Configure credentials
- [ ] **Test locally** - Use `supabase functions serve`
- [ ] **Deploy to production** - Use `supabase functions deploy`
- [ ] **Update iOS app** - Call new Edge Function endpoint
- [ ] **Monitor logs** - Check for errors in production
- [ ] **Test end-to-end** - Verify full flow works
- [ ] **Document changes** - Update API documentation

---

## 📚 Additional Resources

- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Plaid API Reference](https://plaid.com/docs/api/)
- [Deno Runtime Docs](https://deno.com/runtime)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)

---

## 🐛 Troubleshooting

### "Module not found" Error

**Problem**: Import statement fails with "Module not found"

**Solution**: Use `npm:` prefix for npm packages in Deno:
```typescript
import { PlaidApi } from 'npm:plaid@31.1.0';  // ✅ Correct
import { PlaidApi } from 'plaid';             // ❌ Wrong
```

### "Missing Plaid configuration" Error

**Problem**: Function throws error about missing env vars

**Solution**: Set environment secrets:
```bash
supabase secrets set PLAID_CLIENT_ID=your_id
supabase secrets set PLAID_SECRET=your_secret
```

### "Unauthorized" Error

**Problem**: Getting 401 response from function

**Solution**:
1. Verify JWT token is valid (check expiration)
2. Check Authorization header format: `Bearer <token>`
3. Ensure user is signed in with Supabase Auth

### "Failed to retrieve item" Error

**Problem**: Can't find item in database

**Solution**:
1. Verify item exists: `SELECT * FROM items WHERE id = <itemId>`
2. Check RLS policies allow user to read item
3. Verify item belongs to authenticated user

---

## 💡 Performance Tips

### Cold Starts

Edge Functions may have cold starts (first request after idle):
- **Expected**: 1-3 seconds for first request
- **Subsequent requests**: <100ms

To minimize cold starts:
- Keep functions warm with periodic pings
- Optimize imports (only import what you need)
- Use shared utilities (`_shared/`)

### Request Timeouts

Limits:
- **CPU time**: 50 seconds (free tier), 200 seconds (pro)
- **Wall-clock time**: 150 seconds (free tier), 400 seconds (pro)

**Note**: Network I/O (Plaid API calls, database queries) doesn't count toward CPU time!

---

## 🎉 Success Indicators

Your Edge Function is working correctly if:

✅ Deployment succeeds without errors
✅ Function appears in `supabase functions list`
✅ Logs show successful link token creation
✅ iOS app receives valid link_token
✅ Plaid Link opens successfully in app
✅ No errors in Supabase dashboard

Congratulations - you've migrated your first route to Supabase! 🚀
