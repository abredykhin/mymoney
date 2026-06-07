import { createServiceRoleClient, requireAuth, handleCors, jsonResponse } from '../_shared/auth.ts';
import { createPlaidClient } from '../_shared/plaid.ts';
import { updateTransactionRecurringFlags, updateProfileRecurringSummary } from '../_shared/recurring.ts';

interface SyncRequest {
  plaid_item_id: string;
  user_id: string;
}

interface SyncResult {
  success: boolean;
  streamsProcessed: number;
}

Deno.serve(async (req: Request) => {
  // Handle CORS
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const body: SyncRequest = await req.json();
    const { plaid_item_id, user_id } = body;

    if (!plaid_item_id || !user_id) {
      return jsonResponse({ error: 'Missing required parameters' }, 400);
    }

    console.log(`🔄 Starting recurring transaction sync for item: ${plaid_item_id}`);

    const result = await syncRecurringTransactions(plaid_item_id, user_id);

    return jsonResponse(result);
  } catch (error: any) {
    console.error('❌ Recurring sync failed:', error);
    return jsonResponse({ error: error.message }, 500);
  }
});

async function syncRecurringTransactions(
  plaidItemId: string,
  userId: string
): Promise<SyncResult> {

  const supabase = createServiceRoleClient();

  // 1. Fetch item details
  const { data: item, error: itemError } = await supabase
    .from('items_table')
    .select('id, plaid_access_token')
    .eq('plaid_item_id', plaidItemId)
    .single();

  if (itemError || !item) {
    throw new Error(`Item not found: ${plaidItemId}`);
  }

  // 2. Call Plaid recurring endpoint
  console.log('📞 Calling Plaid /transactions/recurring/get');
  const plaidClient = createPlaidClient();
  const response = await callPlaidWithRetry(
    () =>
      plaidClient.transactionsRecurringGet({
        access_token: item.plaid_access_token,
        options: {
          include_personal_finance_category: true
        }
      }),
    plaidItemId
  );

  const { inflow_streams, outflow_streams } = response.data;
  console.log(`📊 Received ${inflow_streams.length} income streams, ${outflow_streams.length} expense streams`);

  // 3. Process and upsert streams
  const allStreams = [
    ...inflow_streams.map((s: any) => ({ ...s, type: 'income' })),
    ...outflow_streams.map((s: any) => ({ ...s, type: 'expense' }))
  ];

  for (const stream of allStreams) {
    // Get account_id for this stream (accounts_table has item_id, not user_id)
    const { data: account } = await supabase
      .from('accounts_table')
      .select('id')
      .eq('plaid_account_id', stream.account_id)
      .eq('item_id', item.id)
      .single();

    if (!account) {
      console.warn(`  Account not found for stream ${stream.stream_id}, skipping`);
      continue;
    }

    // Check for existing stream to preserve user overrides
    const { data: existingStreams } = await supabase
      .from('recurring_streams_table')
      .select('id, user_marked_recurring, is_excluded')
      .eq('user_id', userId)
      .eq('plaid_stream_id', stream.stream_id);

    const existing = existingStreams?.[0];

    const streamData = {
      user_id: userId,
      item_id: item.id,
      account_id: account.id,
      plaid_stream_id: stream.stream_id,
      description: stream.description,
      merchant_name: stream.merchant_name || null,
      personal_finance_category: stream.personal_finance_category?.primary || null,
      personal_finance_subcategory: stream.personal_finance_category?.detailed || null,
      frequency: stream.frequency, // Keep as-is: WEEKLY, SEMI_MONTHLY, MONTHLY, ANNUALLY
      average_amount: Math.abs(stream.average_amount.amount),
      last_amount: Math.abs(stream.last_amount?.amount || 0),
      monthly_amount: calculateMonthlyAmount(stream),
      iso_currency_code: stream.average_amount.iso_currency_code || 'USD',
      type: stream.type,
      status: stream.status, // Keep as-is: MATURE, etc.
      is_active: stream.is_active,
      is_user_modified: stream.is_user_modified || false,
      first_date: stream.first_date,
      last_date: stream.last_date,
      predicted_next_date: stream.predicted_next_date || null,
      is_manual: false,
      last_synced_at: new Date().toISOString(),
      // Preserve user overrides if they exist
      user_marked_recurring: existing?.user_marked_recurring ?? null,
      is_excluded: existing?.is_excluded ?? false
    };

    // Manual upsert: update if exists, insert otherwise
    // NOTE: Can't use .upsert() with onConflict because our UNIQUE constraint is a partial index
    if (existing) {
      const { error: updateError } = await supabase
        .from('recurring_streams_table')
        .update(streamData)
        .eq('id', existing.id);

      if (updateError) {
        console.error(`❌ Failed to update stream ${stream.stream_id}:`, updateError);
        continue;
      }
    } else {
      const { error: insertError } = await supabase
        .from('recurring_streams_table')
        .insert(streamData);

      if (insertError) {
        console.error(`❌ Failed to insert stream ${stream.stream_id}:`, insertError);
        continue;
      }
    }

    // 4. Link transactions to stream
    await linkTransactionsToStream(supabase, stream, userId);
  }

  // 5. Process manual streams (user-created patterns)
  console.log('📍 Step 5: Process manual streams');
  await syncManualStreams(supabase, userId);

  // 6. Update is_recurring flags on transactions
  await updateTransactionRecurringFlags(supabase as any, userId);

  // 7. Update profile monthly totals
  await updateProfileRecurringSummary(supabase as any, userId);

  console.log(`✅ Recurring sync completed: ${allStreams.length} Plaid streams processed`);

  return { success: true, streamsProcessed: allStreams.length };
}

async function syncManualStreams(supabase: any, userId: string): Promise<void> {
  // Fetch all active manual streams for this user
  const { data: manualStreams } = await supabase
    .from('recurring_streams_table')
    .select('id, match_pattern, description')
    .eq('user_id', userId)
    .eq('is_manual', true)
    .eq('is_active', true);

  if (!manualStreams || manualStreams.length === 0) {
    console.log('  No manual streams to process');
    return;
  }

  console.log(`  Processing ${manualStreams.length} manual streams`);

  for (const stream of manualStreams) {
    // Find all transactions matching this pattern
    const { data: matchingTransactions } = await supabase
      .from('transactions_table')
      .select('id')
      .eq('user_id', userId)
      .ilike('name', `%${stream.match_pattern}%`);

    if (!matchingTransactions || matchingTransactions.length === 0) {
      console.log(`  No matches for pattern: ${stream.match_pattern}`);
      continue;
    }

    console.log(`  Found ${matchingTransactions.length} transactions matching "${stream.match_pattern}"`);

    // Link these transactions to the manual stream
    const junctionRecords = matchingTransactions.map((tx: any) => ({
      stream_id: stream.id,
      transaction_id: tx.id
    }));

    await supabase
      .from('recurring_stream_transactions_table')
      .upsert(junctionRecords, { onConflict: 'stream_id,transaction_id', ignoreDuplicates: true });
  }
}

async function linkTransactionsToStream(
  supabase: any,
  stream: any,
  userId: string
): Promise<void> {
  // Get stream's internal ID
  const { data: streamRecord } = await supabase
    .from('recurring_streams_table')
    .select('id')
    .eq('plaid_stream_id', stream.stream_id)
    .single();

  if (!streamRecord) return;

  // Fetch transactions by Plaid transaction IDs
  const { data: transactions } = await supabase
    .from('transactions_table')
    .select('id')
    .in('transaction_id', stream.transaction_ids)
    .eq('user_id', userId);

  if (!transactions || transactions.length === 0) return;

  // Create junction records
  const junctionRecords = transactions.map((tx: any) => ({
    stream_id: streamRecord.id,
    transaction_id: tx.id
  }));

  await supabase
    .from('recurring_stream_transactions_table')
    .upsert(junctionRecords, { onConflict: 'stream_id,transaction_id', ignoreDuplicates: true });
}

function calculateMonthlyAmount(stream: any): number {
  const amount = Math.abs(stream.average_amount.amount);
  const frequency = stream.frequency;

  const multipliers: Record<string, number> = {
    'WEEKLY': 52 / 12,          // ~4.33 times per month
    'SEMI_MONTHLY': 2,          // Twice per month (e.g., 1st and 15th)
    'MONTHLY': 1,               // Once per month
    'ANNUALLY': 1 / 12          // Once per year
  };

  const multiplier = multipliers[frequency];

  if (multiplier === undefined) {
    console.warn(`⚠️ Unknown frequency: ${frequency}, defaulting to monthly`);
    return amount;
  }

  return amount * multiplier;
}

/**
 * Helper to format frequency for display
 */
function formatFrequencyForDisplay(plaidFrequency: string): string {
  const mapping: Record<string, string> = {
    'WEEKLY': 'Weekly',
    'SEMI_MONTHLY': 'Twice Monthly',
    'MONTHLY': 'Monthly',
    'ANNUALLY': 'Yearly'
  };
  return mapping[plaidFrequency] || plaidFrequency;
}

/**
 * Retry logic with exponential backoff for rate limit errors
 */
async function callPlaidWithRetry<T>(
  fn: () => Promise<T>,
  plaidItemId?: string,
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
      if (error.response?.data?.error_code === 'ITEM_LOGIN_REQUIRED') {
        console.error('❌ Item requires re-authentication');
        // Mark item as requiring user action
        if (plaidItemId) {
          await markItemAsNeedsReauth(
            plaidItemId,
            error.response?.data?.error_message || 'Item requires user re-authentication'
          );
        }
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
