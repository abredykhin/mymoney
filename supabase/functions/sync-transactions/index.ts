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
import { fetchTransactionUpdates, fetchAccountBalances } from './plaid.ts';
import type { SyncRequest, SyncResponse } from './types.ts';

/**
 * Main Deno serve handler
 */
Deno.serve(async (req: Request, ctx: any) => {
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
    const startTime = Date.now();

    // Execute sync
    const result = await syncTransactions(plaid_item_id, ctx);

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
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
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
async function syncTransactions(plaidItemId: string, ctx?: any): Promise<{
  added: number;
  modified: number;
  removed: number;
}> {
  // Create service role client (bypasses RLS for webhook context)
  const supabase = createServiceRoleClient();

  // Step 1: Fetch item details from database
  console.log('📍 Step 1: Fetch item details');
  const item = await fetchItemDetails(supabase, plaidItemId);

  // Step 2: Fetch transaction updates from Plaid
  console.log('📍 Step 2: Fetch transaction updates from Plaid');
  const { added, modified, removed, nextCursor } = await fetchTransactionUpdates(item);

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

  // Trigger Gemini Budget Analysis in the background
  // Only trigger if it's the first sync (historical) or we have many new transactions
  const isFirstSync = !item.transactions_cursor;
  if (isFirstSync || added.length > 50) {
    if (ctx && typeof ctx.waitUntil === 'function') {
      ctx.waitUntil(triggerBudgetAnalysis(item.user_id as string));
    } else {
      triggerBudgetAnalysis(item.user_id as string).catch(err => console.error('Budget analysis trigger failed:', err));
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
    nextCursor: string;
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

/**
 * Trigger Gemini Budget Analysis Edge Function
 */
async function triggerBudgetAnalysis(userId: string) {
  try {
    console.log(`🚀 Triggering budget analysis for user: ${userId}`);

    const supabaseUrl = Deno.env.get('CUSTOM_SUPABASE_URL') || Deno.env.get('SUPABASE_URL');
    const functionUrl = supabaseUrl
      ? `${supabaseUrl}/functions/v1/gemini-budget-analysis`
      : 'http://localhost:54321/functions/v1/gemini-budget-analysis';

    const serviceRoleKey = Deno.env.get('CUSTOM_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    await fetch(functionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({ user_id: userId }),
    });
  } catch (error) {
    console.error(`❌ Error triggering budget analysis:`, error);
  }
}
