/**
 * Supabase Edge Function: sync-transactions (STUB)
 *
 * Fetches transaction updates from Plaid and syncs them to the database.
 *
 * Phase 3.3 - Migrated from server/controllers/transactions.js
 *
 * STATUS: This is a stub implementation for testing webhooks.
 *         The real sync logic will be implemented later.
 */

import { createServiceRoleClient } from '../_shared/auth.ts';

interface SyncRequest {
  plaid_item_id: string;
}

/**
 * Main sync handler
 */
Deno.serve(async (req) => {
  console.log('🔄 Sync transactions function called');

  // Only accept POST requests
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    // Parse request body
    const body: SyncRequest = await req.json();
    const { plaid_item_id } = body;

    if (!plaid_item_id) {
      console.error('❌ Missing plaid_item_id in request');
      return new Response(
        JSON.stringify({ error: 'Missing plaid_item_id' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log(`📊 Starting transaction sync for item: ${plaid_item_id}`);

    // ============================================
    // STUB: Real implementation will go here
    // ============================================
    //
    // TODO: Implement the following steps:
    //
    // 1. Look up item in database to get access token and cursor
    //    const supabase = createServiceRoleClient();
    //    const { data: item } = await supabase
    //      .from('items')
    //      .select('plaid_access_token, transactions_cursor, user_id')
    //      .eq('plaid_item_id', plaid_item_id)
    //      .single();
    //
    // 2. Fetch transactions from Plaid using transactions/sync
    //    const plaidClient = createPlaidClient();
    //    let added = [], modified = [], removed = [];
    //    let hasMore = true;
    //    while (hasMore) {
    //      const response = await plaidClient.transactionsSync({
    //        access_token: item.plaid_access_token,
    //        cursor: item.transactions_cursor,
    //        count: 100,
    //      });
    //      added.push(...response.data.added);
    //      modified.push(...response.data.modified);
    //      removed.push(...response.data.removed);
    //      hasMore = response.data.has_more;
    //    }
    //
    // 3. Get updated account balances
    //    const accountsResponse = await plaidClient.accountsGet({
    //      access_token: item.plaid_access_token,
    //    });
    //
    // 4. Batch upsert transactions (CRITICAL: use single query!)
    //    await batchUpsertTransactions(supabase, added.concat(modified), item.user_id);
    //
    // 5. Batch delete removed transactions
    //    await batchDeleteTransactions(supabase, removed);
    //
    // 6. Update accounts and cursor
    //    await updateAccounts(supabase, plaid_item_id, accountsResponse.data.accounts);
    //    await updateCursor(supabase, plaid_item_id, nextCursor);
    //
    // ============================================

    // Simulate processing delay
    await new Promise(resolve => setTimeout(resolve, 1000));

    console.log(`✅ [STUB] Sync completed for item: ${plaid_item_id}`);
    console.log(`   This is a stub - no actual sync performed yet`);

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Sync completed (stub)',
        plaid_item_id,
        stub: true,
        added: 0,
        modified: 0,
        removed: 0,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('❌ Error syncing transactions:', error);

    return new Response(
      JSON.stringify({
        error: 'Sync failed',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }
});

/**
 * DEPLOYMENT & TESTING
 *
 * Deploy:
 *   $ cd supabase
 *   $ supabase functions deploy sync-transactions
 *
 * Test locally:
 *   $ supabase functions serve sync-transactions
 *
 * Test with curl:
 *   ```bash
 *   curl -X POST 'http://localhost:54321/functions/v1/sync-transactions' \
 *     -H "Content-Type: application/json" \
 *     -H "Authorization: Bearer [service-role-key]" \
 *     -d '{"plaid_item_id": "test-item-123"}'
 *   ```
 *
 * Test via webhook:
 *   1. Start both functions:
 *      $ supabase functions serve
 *   2. Send webhook:
 *      $ curl -X POST 'http://localhost:54321/functions/v1/plaid-webhook' \
 *        -H "Content-Type: application/json" \
 *        -d '{
 *          "webhook_type": "TRANSACTIONS",
 *          "webhook_code": "SYNC_UPDATES_AVAILABLE",
 *          "item_id": "test-item-123"
 *        }'
 *   3. Check logs to see sync was triggered
 *
 * NEXT STEPS:
 *
 * Before implementing the real sync logic:
 * 1. Fix batch insert inefficiency in server/db/queries/transactions.js
 * 2. Test the fixed batch insert with legacy backend
 * 3. Port the batch insert logic to this function
 * 4. Implement full sync flow (see TODO comments above)
 */
