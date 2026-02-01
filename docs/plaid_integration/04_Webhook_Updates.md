## 2.6 Critical: Webhook Flow Architecture

**IMPORTANT:** We cannot call `/transactions/recurring/get` immediately after account linking. Plaid requires historical transaction data to be fully loaded first.

### The Correct Sequence:

```
1. User links account
   ↓
2. save-item creates Item (historical_sync_complete = FALSE)
   ↓
3. Plaid begins fetching historical transactions
   ↓
4. Multiple SYNC_UPDATES_AVAILABLE webhooks arrive
   ↓
5. sync-transactions runs repeatedly, fetching transaction batches
   ↓
6. Eventually: SYNC_UPDATES_AVAILABLE with historical_update_complete = TRUE
   ↓
7. Update items_table: SET historical_sync_complete = TRUE
   ↓
8. ✅ NOW trigger sync-recurring-transactions for the first time
   ↓
9. Subscribe to RECURRING_TRANSACTIONS_UPDATE webhook for future updates
```

### Ongoing Updates After Initial Load:

```
Plaid detects recurring pattern changes
   ↓
RECURRING_TRANSACTIONS_UPDATE webhook fires
   ↓
sync-recurring-transactions runs again
```

**Key Requirements:**
- Must subscribe to `RECURRING_TRANSACTIONS_UPDATE` webhook in Plaid Dashboard
- Must check `historical_update_complete` field in webhook payload
- Must track completion state in `items_table`
- Must not call `/transactions/recurring/get` before historical data is complete

---
## 4. Update `plaid-webhook` Function

Modify `/supabase/functions/plaid-webhook/index.ts` to handle recurring transaction webhooks:

### 4.1 Update Webhook Body Interface

```typescript
interface PlaidWebhookBody {
  webhook_type: 'TRANSACTIONS' | 'ITEM' | 'AUTH' | 'ASSETS' | string;
  webhook_code: string;
  item_id: string;
  error?: {
    error_code: string;
    error_message: string;
  };
  new_transactions?: number;
  removed_transactions?: string[];
  historical_update_complete?: boolean; // Critical for recurring sync timing
  initial_update_complete?: boolean;
  account_ids?: string[]; // NEW: For RECURRING_TRANSACTIONS_UPDATE webhook
  environment: string; // "production" or "sandbox"
}
```

### 4.2 Update `handleTransactionWebhook` Function

Replace the existing function with this updated version:

```typescript
async function handleTransactionWebhook(code: string, body: PlaidWebhookBody) {
  console.log(`📊 Processing transaction webhook: ${code}`);

  switch (code) {
    case 'SYNC_UPDATES_AVAILABLE':
      console.log(`🔄 Sync updates available for item ${body.item_id}`);
      console.log(`   New transactions: ${body.new_transactions || 0}`);
      console.log(`   Historical complete: ${body.historical_update_complete || false}`);

      // Trigger transaction sync
      await triggerTransactionSync(body.item_id, body.historical_update_complete || false);
      break;

    case 'RECURRING_TRANSACTIONS_UPDATE':
      // NEW: Handle recurring transaction pattern updates from Plaid
      console.log(`🔁 Recurring transactions updated for item ${body.item_id}`);
      if (body.account_ids) {
        console.log(`   Affected accounts: ${body.account_ids.join(', ')}`);
      }

      // Only trigger if historical sync is complete
      const canSyncRecurring = await checkHistoricalSyncComplete(body.item_id);
      if (canSyncRecurring) {
        await triggerRecurringSync(body.item_id);
      } else {
        console.log(`   ⚠️ Skipping recurring sync - historical data not yet complete`);
      }
      break;

    case 'DEFAULT_UPDATE':
    case 'INITIAL_UPDATE':
    case 'HISTORICAL_UPDATE':
      // These are deprecated when using transactions/sync endpoint
      console.log(`ℹ️  Ignoring deprecated transaction webhook: ${code}`);
      break;

    default:
      console.log(`⚠️  Unhandled transaction webhook code: ${code}`);
  }
}
```

### 4.3 Add Helper Functions

```typescript
/**
 * Check if historical sync is complete for an item
 */
async function checkHistoricalSyncComplete(plaidItemId: string): Promise<boolean> {
  try {
    const supabase = createServiceRoleClient();

    const { data: item, error } = await supabase
      .from('items_table')
      .select('historical_sync_complete')
      .eq('plaid_item_id', plaidItemId)
      .single();

    if (error || !item) {
      console.error(`❌ Failed to check historical sync status: ${error?.message}`);
      return false;
    }

    return item.historical_sync_complete === true;
  } catch (error) {
    console.error(`❌ Error checking historical sync status:`, error);
    return false;
  }
}

/**
 * Trigger recurring transaction sync
 */
async function triggerRecurringSync(plaidItemId: string) {
  try {
    console.log(`🔁 Triggering recurring sync for item: ${plaidItemId}`);

    const supabaseUrl = Deno.env.get('CUSTOM_SUPABASE_URL') || Deno.env.get('SUPABASE_URL');
    const functionUrl = supabaseUrl
      ? `${supabaseUrl}/functions/v1/sync-recurring-transactions`
      : 'http://localhost:54321/functions/v1/sync-recurring-transactions';

    const serviceRoleKey = Deno.env.get('CUSTOM_SERVICE_ROLE_KEY') ||
                          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    // Get user_id for this item
    const supabase = createServiceRoleClient();
    const { data: item } = await supabase
      .from('items_table')
      .select('user_id')
      .eq('plaid_item_id', plaidItemId)
      .single();

    if (!item) {
      console.error(`❌ Item not found: ${plaidItemId}`);
      return;
    }

    await fetch(functionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({
        plaid_item_id: plaidItemId,
        user_id: item.user_id
      }),
    });

    console.log(`✅ Recurring sync triggered for item ${plaidItemId}`);
  } catch (error) {
    console.error(`❌ Error triggering recurring sync:`, error);
  }
}
```

### 4.4 Update `triggerTransactionSync` Function

Add the `historicalComplete` parameter and logic:

```typescript
async function triggerTransactionSync(plaidItemId: string, historicalComplete: boolean) {
  try {
    console.log(`🚀 Triggering sync for item: ${plaidItemId}`);
    console.log(`📦 Historical complete: ${historicalComplete}`);

    const supabaseUrl = Deno.env.get('CUSTOM_SUPABASE_URL') || Deno.env.get('SUPABASE_URL');
    const functionUrl = supabaseUrl
      ? `${supabaseUrl}/functions/v1/sync-transactions`
      : 'http://localhost:54321/functions/v1/sync-transactions';

    const serviceRoleKey = Deno.env.get('CUSTOM_SERVICE_ROLE_KEY') ||
                          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    const payload = {
      plaid_item_id: plaidItemId,
      historical_complete: historicalComplete // Pass this flag to sync-transactions
    };

    const response = await fetch(functionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ Sync trigger failed: ${response.status} - ${errorText}`);
    } else {
      console.log(`✅ Sync triggered successfully for item ${plaidItemId}`);
    }
  } catch (error) {
    console.error(`❌ Error triggering sync:`, error);
  }
}
```
