# Testing Plaid Webhook & Sync Functions

This guide shows you how to test the `plaid-webhook` and `sync-transactions` Edge Functions locally.

## Quick Start

### 1. Start Supabase locally

```bash
cd supabase
supabase start
```

This will start:
- Supabase Studio (for viewing database)
- Edge Functions runtime
- PostgreSQL database

**Save the output!** You'll need:
- `API URL`: e.g., `http://127.0.0.1:54321`
- `service_role key`: Used to call functions as admin

### 2. Serve the functions locally

In a new terminal (from the project root):

```bash
supabase functions serve --no-verify-jwt
```

This will automatically serve all functions in `supabase/functions/`. You should see:
```
Serving functions on http://127.0.0.1:54321/functions/v1/<function-name>
  - http://127.0.0.1:54321/functions/v1/plaid-webhook
  - http://127.0.0.1:54321/functions/v1/sync-transactions
  - ... (other functions)
```

**Note**: The `--no-verify-jwt` flag disables JWT verification for easier local testing.

### 3. Test the webhook

Open another terminal and run:

```bash
# Test SYNC_UPDATES_AVAILABLE webhook
curl -X POST 'http://127.0.0.1:54321/functions/v1/plaid-webhook' \
  -H "Content-Type: application/json" \
  -d '{
    "webhook_type": "TRANSACTIONS",
    "webhook_code": "SYNC_UPDATES_AVAILABLE",
    "item_id": "test-item-123",
    "new_transactions": 5
  }'
```

**Expected output:**
```json
{"status":"received"}
```

**Check the function logs** (in the terminal where you ran `supabase functions serve`):
```
🔔 Incoming Plaid webhook
📦 Webhook type: TRANSACTIONS, code: SYNC_UPDATES_AVAILABLE
🔄 Sync updates available for item test-item-123
   New transactions: 5
🚀 Triggering sync for item: test-item-123
✅ Sync triggered successfully for item test-item-123
```

And in the sync-transactions logs:
```
🔄 Sync transactions function called
📊 Starting transaction sync for item: test-item-123
✅ [STUB] Sync completed for item: test-item-123
   This is a stub - no actual sync performed yet
```

## Testing Different Webhook Types

### Transaction Sync
```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/plaid-webhook' \
  -H "Content-Type: application/json" \
  -d '{
    "webhook_type": "TRANSACTIONS",
    "webhook_code": "SYNC_UPDATES_AVAILABLE",
    "item_id": "test-item-123",
    "new_transactions": 10
  }'
```

### Item Error (Login Required)
```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/plaid-webhook' \
  -H "Content-Type: application/json" \
  -d '{
    "webhook_type": "ITEM",
    "webhook_code": "ERROR",
    "item_id": "test-item-123",
    "error": {
      "error_code": "ITEM_LOGIN_REQUIRED",
      "error_message": "User needs to reconnect their bank account"
    }
  }'
```

### Login Repaired
```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/plaid-webhook' \
  -H "Content-Type: application/json" \
  -d '{
    "webhook_type": "ITEM",
    "webhook_code": "LOGIN_REPAIRED",
    "item_id": "test-item-123"
  }'
```

### New Accounts Available
```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/plaid-webhook' \
  -H "Content-Type: application/json" \
  -d '{
    "webhook_type": "ITEM",
    "webhook_code": "NEW_ACCOUNTS_AVAILABLE",
    "item_id": "test-item-123"
  }'
```

## Testing Sync Function Directly

You can also call the sync function directly (useful for debugging):

```bash
# Get your service role key from `supabase status`
SERVICE_ROLE_KEY="your-service-role-key-here"

curl -X POST 'http://127.0.0.1:54321/functions/v1/sync-transactions' \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -d '{
    "plaid_item_id": "test-item-123"
  }'
```

**Expected response:**
```json
{
  "success": true,
  "message": "Sync completed (stub)",
  "plaid_item_id": "test-item-123",
  "stub": true,
  "added": 0,
  "modified": 0,
  "removed": 0
}
```

## What to Look For

### ✅ Success indicators:
- Webhook returns `{"status":"received"}` immediately
- Logs show "🚀 Triggering sync for item: ..."
- Logs show "✅ Sync triggered successfully..."
- Sync function logs show "🔄 Sync transactions function called"
- Sync function logs show "✅ [STUB] Sync completed..."

### ❌ Common issues:

**Issue**: "Connection refused" when triggering sync
- **Cause**: sync-transactions function not running
- **Fix**: Make sure you ran `supabase functions serve --no-verify-jwt` from the project root

**Issue**: Webhook returns error
- **Cause**: Invalid JSON or missing fields
- **Fix**: Check the webhook payload structure

**Issue**: No logs appear
- **Cause**: Functions not running or logs not visible
- **Fix**: Make sure you're watching the correct terminal window

## Environment Variables

For local testing, create `supabase/.env` (already exists, check it):

```bash
# Plaid credentials
PLAID_CLIENT_ID=your_client_id
PLAID_SECRET=your_secret
PLAID_ENV=sandbox

# Supabase URLs (auto-set by local dev, but can override)
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_from_supabase_start

# Local dev flag
IS_LOCAL_DEV=true
```

## Production Deployment

When you're ready to deploy:

```bash
cd supabase
supabase functions deploy plaid-webhook
supabase functions deploy sync-transactions
```

Then configure Plaid webhook URL in Plaid Dashboard:
```
https://[your-project-ref].supabase.co/functions/v1/plaid-webhook
```

## Testing with Real Plaid Webhooks (Optional)

If you want to test with real Plaid webhook events:

### Option 1: ngrok (easiest)

1. Install ngrok: https://ngrok.com/download

2. Start your local functions (from project root):
   ```bash
   supabase functions serve --no-verify-jwt
   ```

3. In another terminal, expose the webhook:
   ```bash
   ngrok http 54321
   ```

4. Copy the HTTPS URL (e.g., `https://abc123.ngrok.io`)

5. Update Plaid webhook URL:
   ```
   https://abc123.ngrok.io/functions/v1/plaid-webhook
   ```

6. Trigger a sync in your app → Plaid will send real webhook to your local function!

### Option 2: Deploy to production and test there

Simpler for quick tests, but less ideal for development.

## Next Steps

Once webhook is working:

1. **Implement real sync logic** in `sync-transactions/index.ts`
2. **Fix batch insert** inefficiency in legacy code first
3. **Port batch insert** logic to the new function
4. **Test with real Plaid items** from your database

---

## Troubleshooting

### Check function logs
```bash
# View logs from Supabase Studio
open http://127.0.0.1:54323
# Navigate to Edge Functions → Logs
```

### View Supabase database
```bash
# Open Studio
open http://127.0.0.1:54323
# Navigate to Table Editor to see items, transactions, etc.
```

### Reset everything
```bash
cd supabase
supabase stop
supabase start
```

---

## Known Local Development Limitations

### `ctx.waitUntil()` Not Available Locally

In local development, the Edge Functions runtime doesn't support `ctx.waitUntil()`. The webhook function handles this gracefully by falling back to async processing without `waitUntil`.

**What this means:**
- ✅ **Production**: Background processing with `ctx.waitUntil()` (non-blocking)
- ✅ **Local dev**: Async processing without `waitUntil` (still works, just different mechanism)

**No action needed** - the function detects the environment and adapts automatically.

## Summary

You now have:
- ✅ Webhook that receives Plaid events
- ✅ Webhook returns 200 OK immediately (Plaid requirement)
- ✅ Webhook triggers sync in background (production) or async (local dev)
- ✅ Stub sync function that logs activity
- ✅ Complete local testing setup

**Next**: Implement the real sync logic once batch inserts are optimized! 🚀
