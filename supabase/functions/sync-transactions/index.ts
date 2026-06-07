/**
 * Supabase Edge Function: sync-transactions
 *
 * Fetches transaction updates from Plaid and syncs them to the database.
 *
 * Phase 3.3 - Migrated from server/controllers/transactions.js
 *
 * PERFORMANCE: Uses efficient batch operations (single queries instead of N queries)
 * to avoid timeout issues in Edge Functions.
 */

import { createServiceRoleClient } from '../_shared/auth.ts';
import {
  fetchItemDetails,
  fetchAccountIdMapping,
  batchUpsertAccounts,
  batchUpsertTransactions,
  batchDeleteTransactions,
  updateCursor,
} from './database.ts';
import { fetchTransactionUpdates, fetchAccountBalances, PlaidItemError } from './plaid.ts';
import type { SyncResponse } from './types.ts';

interface SyncRequest {
  plaid_item_id: string;
  historical_complete?: boolean; // NEW: Flag from webhook
}

/**
 * Main Deno serve handler
 */
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

/**
 * Main sync logic
 *
 * Orchestrates the transaction sync process:
 * 1. Fetch item details from database
 * 2. Fetch transaction updates from Plaid
 * 3. Fetch updated account balances from Plaid
 * 4. Update database with batch operations
 * 5. Update cursor (ONLY after all operations succeed)
 *
 * @param plaidItemId - Plaid item ID
 * @returns Sync counts (added, modified, removed)
 */
async function syncTransactions(
  plaidItemId: string,
  ctx?: any,
  historicalComplete?: boolean
): Promise<{
  added: number;
  modified: number;
  removed: number;
}> {
  // Create service role client (bypasses RLS for webhook context)
  const supabase = createServiceRoleClient();

  // Step 1: Fetch item details from database
  console.log('📍 Step 1: Fetch item details');
  const item = await fetchItemDetails(supabase, plaidItemId);

  // Track if this is the FIRST time historical sync completes
  const wasHistoricalIncomplete = !item.historical_sync_complete;
  const nowHistoricalComplete = historicalComplete === true;

  // Step 2: Fetch transaction updates from Plaid
  console.log('📍 Step 2: Fetch transaction updates from Plaid');
  const { added, modified, removed, nextCursor } = await callPlaidWithRetry(() => fetchTransactionUpdates(item));

  // Step 3: Fetch updated account balances from Plaid
  console.log('📍 Step 3: Fetch account balances from Plaid');
  const accounts = await fetchAccountBalances(item.plaid_access_token);

  // Step 4: Update database with batch operations
  console.log('📍 Step 4: Update database');
  await updateDatabase(supabase, {
    plaidItemId,
    itemId: item.id,
    userId: item.user_id as string,
    added,
    modified,
    removed,
    accounts,
    nextCursor,
  });

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

/**
 * Update database with all sync data
 *
 * Performs batch operations in correct order:
 * 1. Pre-fetch account ID mapping (eliminates N queries in transaction loop)
 * 2. Batch upsert accounts
 * 3. Batch upsert transactions (added + modified)
 * 4. Batch delete removed transactions
 * 5. Update cursor (CRITICAL: only after all operations succeed)
 *
 * @param supabase - Service role Supabase client
 * @param params - All data needed for database updates
 */
async function updateDatabase(
  supabase: any,
  params: {
    plaidItemId: string;
    itemId: number;
    userId: string;
    added: any[];
    modified: any[];
    removed: any[];
    accounts: any[];
    nextCursor: string | null;
  }
) {
  const { plaidItemId, itemId, userId, added, modified, removed, accounts, nextCursor } = params;

  try {
    // Pre-fetch account ID mapping (CRITICAL for performance)
    console.log('  1️⃣  Pre-fetch account ID mapping');
    const accountIdMapping = await fetchAccountIdMapping(supabase, itemId);

    // Update accounts (balances)
    console.log('  2️⃣  Batch upsert accounts');
    await batchUpsertAccounts(supabase, plaidItemId, accounts);

    // Batch upsert transactions (added + modified)
    console.log('  3️⃣  Batch upsert transactions');
    const allTransactions = [...added, ...modified];
    await batchUpsertTransactions(supabase, allTransactions, accountIdMapping, userId);

    // Batch delete removed transactions
    console.log('  4️⃣  Batch delete removed transactions');
    const removedIds = removed.map((r) => r.transaction_id);
    await batchDeleteTransactions(supabase, removedIds);

    // Update cursor (IMPORTANT: only after successful sync)
    console.log('  5️⃣  Update cursor');
    await updateCursor(supabase, plaidItemId, nextCursor);

    console.log('✅ Database update complete');
  } catch (error) {
    console.error('❌ Database update failed - cursor NOT updated:', error);
    throw error;
  }
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

/**
 * Retry logic with exponential backoff for rate limit errors
 */
async function callPlaidWithRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  baseDelay: number = 1000
): Promise<T> {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error: any) {
      // Check for rate limit error (HTTP 429)
      if (error.response?.status === 429) {
        if (attempt === maxRetries) {
          throw new Error(`Rate limit exceeded after ${maxRetries} retries`);
        }

        // Exponential backoff: 1s, 2s, 4s, 8s...
        const delay = baseDelay * Math.pow(2, attempt);
        console.warn(`⚠️ Rate limited, retrying in ${delay}ms (attempt ${attempt + 1}/${maxRetries})`);
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }

      // Check for invalid access token (ITEM_LOGIN_REQUIRED)
      if (error instanceof PlaidItemError && error.code === 'ITEM_LOGIN_REQUIRED') {
        console.error('❌ Item requires re-authentication');
        // Mark item as requiring user action
        await markItemAsNeedsReauth(error.plaidItemId, error.message);
        throw new Error('Item requires re-authentication');
      }

      if (error.response?.data?.error_code === 'ITEM_LOGIN_REQUIRED') {
        console.error('❌ Item requires re-authentication');
        throw new Error('Item requires re-authentication');
      }

      // Check for network/timeout errors
      if (error.code === 'ETIMEDOUT' || error.code === 'ECONNREFUSED') {
        if (attempt === maxRetries) {
          throw new Error(`Network error after ${maxRetries} retries: ${error.code}`);
        }
        const delay = baseDelay * Math.pow(2, attempt);
        console.warn(`⚠️ Network error, retrying in ${delay}ms`);
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }

      // All other errors - don't retry
      throw error;
    }
  }

  throw new Error('Unexpected retry loop exit');
}

/**
 * Mark item as needing reauth
 */
async function markItemAsNeedsReauth(plaidItemId: string, message?: string) {
  const supabase = createServiceRoleClient();
  await supabase
    .from('items_table')
    .update({
      status: 'needs_reauth',
      plaid_health_updated_at: new Date().toISOString(),
      plaid_last_error_code: 'ITEM_LOGIN_REQUIRED',
      plaid_last_error_message: message || 'Item requires user re-authentication',
      updated_at: new Date().toISOString()
    })
    .eq('plaid_item_id', plaidItemId);
}

/**
 * DEPLOYMENT & TESTING
 *
 * Deploy:
 *   $ cd /Users/abredykhin/ws/mymoney
 *   $ supabase functions deploy sync-transactions
 *
 * Test locally:
 *   1. Start Supabase:
 *      $ cd supabase && supabase start
 *
 *   2. Serve functions:
 *      $ supabase functions serve --no-verify-jwt
 *
 *   3. Get service role key from `supabase status` output
 *
 *   4. Test with curl:
 *      ```bash
 *      curl -X POST 'http://localhost:54321/functions/v1/sync-transactions' \
 *        -H "Content-Type: application/json" \
 *        -H "Authorization: Bearer [service-role-key]" \
 *        -d '{"plaid_item_id": "your-test-item-id"}'
 *      ```
 *
 * Test via webhook:
 *   1. Ensure functions are served: `supabase functions serve --no-verify-jwt`
 *
 *   2. Send webhook to trigger sync:
 *      ```bash
 *      curl -X POST 'http://localhost:54321/functions/v1/plaid-webhook' \
 *        -H "Content-Type: application/json" \
 *        -d '{
 *          "webhook_type": "TRANSACTIONS",
 *          "webhook_code": "SYNC_UPDATES_AVAILABLE",
 *          "item_id": "your-test-item-id"
 *        }'
 *      ```
 *
 *   3. Check logs to see sync was triggered and completed
 *
 * PERFORMANCE IMPROVEMENT:
 *
 * Legacy (Node.js):
 *   - 300 individual transaction INSERTs (one per transaction)
 *   - 300 account lookups inside loop
 *   - Result: ~20-30 seconds, risk of timeout
 *
 * Supabase (Edge Function):
 *   - 1 batch INSERT for all transactions
 *   - 1 pre-fetch query for account mappings
 *   - Result: ~2-3 seconds, no timeout risk
 *
 * CRITICAL SUCCESS FACTORS:
 *   1. Pre-fetch account ID mapping (eliminates N queries)
 *   2. Single batch upsert for transactions (not N queries)
 *   3. Single batch delete for removed transactions
 *   4. Cursor updated ONLY after all operations succeed
 */
