## 8. Plaid Dashboard Configuration

**CRITICAL:** You must subscribe to the `RECURRING_TRANSACTIONS_UPDATE` webhook in your Plaid Dashboard:

1. Log into [Plaid Dashboard](https://dashboard.plaid.com/)
2. Navigate to **Webhooks** section
3. Ensure your webhook URL is configured:
   ```
   https://[your-project-ref].supabase.co/functions/v1/plaid-webhook
   ```
4. Subscribe to these webhook types:
   - ✅ `TRANSACTIONS` → `SYNC_UPDATES_AVAILABLE`
   - ✅ `TRANSACTIONS` → `RECURRING_TRANSACTIONS_UPDATE` (NEW)
   - ✅ `ITEM` → All item events

Without subscribing to `RECURRING_TRANSACTIONS_UPDATE`, your app will never know when Plaid detects new recurring patterns or when existing patterns change.
