/**
 * Database operations for sync-transactions Edge Function
 *
 * Implements efficient batch operations to minimize database round-trips.
 * CRITICAL: Uses single batch queries instead of N individual queries.
 */

import { SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import type { Item, PlaidTransaction, PlaidAccount } from './types.ts';

/**
 * Fetch item details from database
 *
 * @param supabase - Service role Supabase client
 * @param plaidItemId - Plaid item ID
 * @returns Item with access token and cursor
 */
export async function fetchItemDetails(
  supabase: SupabaseClient,
  plaidItemId: string
): Promise<Item> {
  console.log(`🔍 Fetching item details for: ${plaidItemId}`);

  const { data, error } = await supabase
    .from('items_table')
    .select('id, user_id, plaid_access_token, transactions_cursor, plaid_item_id')
    .eq('plaid_item_id', plaidItemId)
    .single();

  if (error || !data) {
    throw new Error(`Item not found: ${plaidItemId} - ${error?.message}`);
  }

  console.log(`✅ Found item: ${data.id} (user: ${data.user_id})`);
  return data;
}

/**
 * Pre-fetch account ID mapping to avoid lookups in transaction loop
 *
 * CRITICAL OPTIMIZATION: This eliminates 300 queries for 300 transactions.
 *
 * @param supabase - Service role Supabase client
 * @param itemId - Internal item ID
 * @returns Map of plaid_account_id → account.id
 */
export async function fetchAccountIdMapping(
  supabase: SupabaseClient,
  itemId: number
): Promise<Map<string, number>> {
  console.log(`🔍 Pre-fetching account ID mapping for item: ${itemId}`);

  const { data, error } = await supabase
    .from('accounts_table')
    .select('id, plaid_account_id')
    .eq('item_id', itemId);

  if (error) {
    throw new Error(`Failed to fetch accounts: ${error.message}`);
  }

  // Create fast lookup map: plaid_account_id → id (O(1) lookups)
  const mapping = new Map<string, number>();
  for (const account of data || []) {
    mapping.set(account.plaid_account_id, account.id);
  }

  console.log(`✅ Loaded ${mapping.size} account mappings`);
  return mapping;
}

/**
 * Batch upsert accounts with updated balances
 *
 * Uses single query with ON CONFLICT for efficient upserts.
 *
 * @param supabase - Service role Supabase client
 * @param plaidItemId - Plaid item ID
 * @param accounts - Array of Plaid accounts with balances
 */
export async function batchUpsertAccounts(
  supabase: SupabaseClient,
  plaidItemId: string,
  accounts: PlaidAccount[]
): Promise<void> {
  if (accounts.length === 0) {
    console.log('ℹ️  No accounts to upsert');
    return;
  }

  console.log(`💰 Batch upserting ${accounts.length} accounts`);

  // Fetch item_id once
  const { data: item, error: itemError } = await supabase
    .from('items_table')
    .select('id')
    .eq('plaid_item_id', plaidItemId)
    .single();

  if (itemError || !item) {
    throw new Error(`Item not found: ${plaidItemId}`);
  }

  // Prepare all account data
  const accountsData = accounts.map((acc) => ({
    item_id: item.id,
    plaid_account_id: acc.account_id,
    name: acc.name,
    mask: acc.mask,
    official_name: acc.official_name || null,
    current_balance: acc.balances.current,
    available_balance: acc.balances.available,
    iso_currency_code: acc.balances.iso_currency_code,
    unofficial_currency_code: acc.balances.unofficial_currency_code || null,
    type: acc.type,
    subtype: acc.subtype,
  }));

  // Single batch upsert - Supabase handles SQL generation
  const { error } = await supabase
    .from('accounts_table')
    .upsert(accountsData, {
      onConflict: 'plaid_account_id',
      ignoreDuplicates: false, // Update balances on conflict
    });

  if (error) {
    throw new Error(`Failed to upsert accounts: ${error.message}`);
  }

  console.log(`✅ Successfully upserted ${accounts.length} accounts`);
}

/**
 * Batch upsert transactions - THE CRITICAL PERFORMANCE FIX
 *
 * Legacy code executed 300 individual INSERT queries (one per transaction).
 * This uses a SINGLE batch upsert query for all transactions.
 *
 * Performance improvement: 20-30 seconds → ~2 seconds for 300 transactions.
 *
 * @param supabase - Service role Supabase client
 * @param transactions - Array of Plaid transactions
 * @param accountIdMapping - Pre-fetched account ID map
 * @param userId - User ID for RLS
 */
export async function batchUpsertTransactions(
  supabase: SupabaseClient,
  transactions: PlaidTransaction[],
  accountIdMapping: Map<string, number>,
  userId: string
): Promise<void> {
  if (transactions.length === 0) {
    console.log('ℹ️  No transactions to upsert');
    return;
  }

  console.log(`📝 Batch upserting ${transactions.length} transactions`);

  // Transform to database format with O(1) account lookups
  const txData = transactions
    .map((tx) => {
      const accountId = accountIdMapping.get(tx.account_id);

      if (!accountId) {
        console.warn(
          `⚠️  Skipping transaction - account not found: ${tx.transaction_id} (account: ${tx.account_id})`
        );
        return null;
      }

      return {
        account_id: accountId,
        user_id: userId,
        amount: tx.amount,
        iso_currency_code: tx.iso_currency_code || null,
        date: tx.date,
        authorized_date: tx.authorized_date || null,
        name: tx.name,
        merchant_name: tx.merchant_name || null,
        logo_url: tx.logo_url || null,
        website: tx.website || null,
        payment_channel: tx.payment_channel,
        transaction_id: tx.transaction_id,
        personal_finance_category: tx.personal_finance_category?.primary || null,
        personal_finance_subcategory: tx.personal_finance_category?.detailed || null,
        pending: tx.pending,
        pending_transaction_transaction_id: tx.pending_transaction_id || null,
      };
    })
    .filter((tx) => tx !== null);

  if (txData.length === 0) {
    console.warn('⚠️  No valid transactions to insert (all missing accounts)');
    return;
  }

  console.log(`📊 Upserting ${txData.length} valid transactions (${transactions.length - txData.length} skipped)`);

  // Single batch upsert - Supabase client handles SQL generation
  const { error } = await supabase
    .from('transactions_table')
    .upsert(txData, {
      onConflict: 'transaction_id',
      ignoreDuplicates: false, // Update on conflict
    });

  if (error) {
    throw new Error(`Batch upsert failed: ${error.message}`);
  }

  console.log(`✅ Successfully upserted ${txData.length} transactions`);
}

/**
 * Batch delete removed transactions
 *
 * Uses single DELETE with IN clause instead of N individual DELETE queries.
 *
 * @param supabase - Service role Supabase client
 * @param plaidTransactionIds - Array of Plaid transaction IDs to delete
 */
export async function batchDeleteTransactions(
  supabase: SupabaseClient,
  plaidTransactionIds: string[]
): Promise<void> {
  if (plaidTransactionIds.length === 0) {
    console.log('ℹ️  No transactions to delete');
    return;
  }

  console.log(`🗑️  Batch deleting ${plaidTransactionIds.length} transactions`);

  // Single DELETE with IN clause
  const { error } = await supabase
    .from('transactions_table')
    .delete()
    .in('transaction_id', plaidTransactionIds);

  if (error) {
    throw new Error(`Batch delete failed: ${error.message}`);
  }

  console.log(`✅ Successfully deleted ${plaidTransactionIds.length} transactions`);
}

/**
 * Update sync cursor in items table
 *
 * CRITICAL: Only call this after ALL operations succeed.
 * If any step fails, the cursor should NOT be updated so the next sync can retry.
 *
 * @param supabase - Service role Supabase client
 * @param plaidItemId - Plaid item ID
 * @param cursor - New cursor value from Plaid
 */
export async function updateCursor(
  supabase: SupabaseClient,
  plaidItemId: string,
  cursor: string
): Promise<void> {
  console.log(`💾 Updating cursor to: ${cursor}`);

  const { error } = await supabase
    .from('items_table')
    .update({ transactions_cursor: cursor })
    .eq('plaid_item_id', plaidItemId);

  if (error) {
    throw new Error(`Failed to update cursor: ${error.message}`);
  }

  console.log(`✅ Cursor updated successfully`);
}
