## 5. Update `sync-transactions` Function

Modify `/supabase/functions/sync-transactions/index.ts` to handle historical completion and trigger recurring sync appropriately:

### 5.1 Update Request Interface

```typescript
interface SyncRequest {
  plaid_item_id: string;
  historical_complete?: boolean; // NEW: Flag from webhook
}
```

### 5.2 Update Main Handler

```typescript
Deno.serve(async (req: Request, ctx: any) => {
  console.log('🔄 Sync transactions function called');

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const body: SyncRequest = await req.json();
    const { plaid_item_id, historical_complete } = body;

    if (!plaid_item_id) {
      console.error('❌ Missing plaid_item_id in request');
      return new Response(
        JSON.stringify({ error: 'Missing plaid_item_id' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log(`📊 Starting transaction sync for item: ${plaid_item_id}`);
    console.log(`📊 Historical complete flag: ${historical_complete}`);

    const startTime = Date.now();

    // Execute sync
    const result = await syncTransactions(plaid_item_id, ctx, historical_complete);

    const elapsed = Date.now() - startTime;
    console.log(`⏱️  Total sync time: ${elapsed}ms`);

    // Return success response
    const response: SyncResponse = {
      success: true,
      message: 'Sync completed successfully',
      plaid_item_id,
      added: result.added,
      modified: result.modified,
      removed: result.removed,
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('❌ Error syncing transactions:', error);
    return new Response(
      JSON.stringify({
        error: 'Sync failed',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
```

### 5.3 Update `syncTransactions` Function

```typescript
async function syncTransactions(
  plaidItemId: string,
  ctx?: any,
  historicalComplete?: boolean
): Promise<{
  added: number;
  modified: number;
  removed: number;
}> {

  const supabase = createServiceRoleClient();

  // Fetch item details
  const item = await fetchItemDetails(supabase, plaidItemId);

  // Track if this is the FIRST time historical sync completes
  const wasHistoricalIncomplete = !item.historical_sync_complete;
  const nowHistoricalComplete = historicalComplete === true;

  // ... existing sync logic ...

  console.log(`✅ Sync completed: +${added.length} ~${modified.length} -${removed.length}`);

  // CRITICAL: If this is the first time historical sync completes, mark it and trigger recurring sync
  if (wasHistoricalIncomplete && nowHistoricalComplete) {
    console.log(`🎉 Historical sync just completed for item ${plaidItemId}`);

    // Mark historical sync as complete in database
    await supabase
      .from('items_table')
      .update({
        historical_sync_complete: true,
        historical_completed_at: new Date().toISOString()
      })
      .eq('plaid_item_id', plaidItemId);

    console.log(`✅ Marked historical sync as complete`);

    // NOW we can trigger recurring sync for the first time
    console.log(`🔁 Triggering INITIAL recurring transaction sync`);
    if (ctx && typeof ctx.waitUntil === 'function') {
      ctx.waitUntil(triggerRecurringSync(plaidItemId, item.user_id as string));
    } else {
      triggerRecurringSync(plaidItemId, item.user_id as string).catch(err =>
        console.error('Recurring sync trigger failed:', err)
      );
    }
  }
  // If historical sync was already complete, trigger recurring sync for updates
  else if (item.historical_sync_complete && added.length > 5) {
    console.log(`🔁 Triggering recurring sync after new transactions`);
    if (ctx && typeof ctx.waitUntil === 'function') {
      ctx.waitUntil(triggerRecurringSync(plaidItemId, item.user_id as string));
    } else {
      triggerRecurringSync(plaidItemId, item.user_id as string).catch(err =>
        console.error('Recurring sync trigger failed:', err)
      );
    }
  }

  return {
    added: added.length,
    modified: modified.length,
    removed: removed.length,
  };
}

async function triggerRecurringSync(plaidItemId: string, userId: string) {
  try {
    console.log(`🔄 Triggering recurring transaction sync for item: ${plaidItemId}`);

    const supabaseUrl = Deno.env.get('CUSTOM_SUPABASE_URL') || Deno.env.get('SUPABASE_URL');
    const functionUrl = supabaseUrl
      ? `${supabaseUrl}/functions/v1/sync-recurring-transactions`
      : 'http://localhost:54321/functions/v1/sync-recurring-transactions';

    const serviceRoleKey = Deno.env.get('CUSTOM_SERVICE_ROLE_KEY') ||
                          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    await fetch(functionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({ plaid_item_id: plaidItemId, user_id: userId }),
    });

    console.log(`✅ Recurring sync triggered successfully`);
  } catch (error) {
    console.error(`❌ Error triggering recurring sync:`, error);
  }
}
```
