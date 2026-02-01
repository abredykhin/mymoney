## 3. Backend: New Edge Function - `sync-recurring-transactions`

Create `/supabase/functions/sync-recurring-transactions/index.ts`:

### Purpose:
- Fetch recurring transaction streams from Plaid
- Sync to `recurring_streams_table`
- Link transactions to streams
- Update transaction `is_recurring` flags
- Respect user overrides

### Triggers:
1. ✅ **After historical sync complete**: `SYNC_UPDATES_AVAILABLE` webhook with `historical_update_complete: true`
2. ✅ **Recurring pattern changes**: `RECURRING_TRANSACTIONS_UPDATE` webhook from Plaid
3. ✅ **After transaction sync**: When new transactions are added (only if historical sync already complete)
4. ✅ **On-demand**: User manually refreshes from iOS app
5. ⚠️ **Periodic background** (optional): Weekly job to catch any missed updates

**CRITICAL:** Never call this function before `items_table.historical_sync_complete = TRUE`

### Key Logic:

```typescript
import { createServiceRoleClient, requireAuth, handleCors, jsonResponse } from '../_shared/auth.ts';
import { createPlaidClient } from '../_shared/plaid.ts';

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
  const response = await plaidClient.transactionsRecurringGet({
    access_token: item.plaid_access_token,
    options: {
      include_personal_finance_category: true
    }
  });

  const { inflow_streams, outflow_streams } = response.data;
  console.log(`📊 Received ${inflow_streams.length} income streams, ${outflow_streams.length} expense streams`);

  // 3. Process and upsert streams
  const allStreams = [
    ...inflow_streams.map((s: any) => ({ ...s, type: 'income' })),
    ...outflow_streams.map((s: any) => ({ ...s, type: 'expense' }))
  ];

  for (const stream of allStreams) {
    // Get account_id for this stream
    const { data: account } = await supabase
      .from('accounts_table')
      .select('id')
      .eq('plaid_account_id', stream.account_id)
      .eq('user_id', userId)
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
  await updateTransactionRecurringFlags(supabase, userId);

  // 7. Update profile monthly totals
  await updateProfileRecurringSummary(supabase, userId);

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

async function updateTransactionRecurringFlags(supabase: any, userId: string): Promise<void> {
  // Mark all transactions as non-recurring initially
  await supabase
    .from('transactions_table')
    .update({ is_recurring: false })
    .eq('user_id', userId);

  // Fetch all active recurring streams (respecting user overrides)
  const { data: streams } = await supabase
    .from('recurring_streams_table')
    .select('id, user_marked_recurring, is_excluded')
    .eq('user_id', userId)
    .eq('is_active', true);

  for (const stream of streams || []) {
    // Determine if this stream should mark transactions as recurring
    // CRITICAL: Exclude TOMBSTONED streams (subscriptions that ended) from budget calculations
    const shouldMarkRecurring =
      stream.user_marked_recurring === true || // User forced recurring
      (stream.user_marked_recurring === null &&
       !stream.is_excluded &&
       stream.status !== 'TOMBSTONED' &&  // Don't include ended subscriptions
       stream.is_active === true); // Plaid says recurring, user didn't override

    if (!shouldMarkRecurring) continue;

    // Get transaction IDs linked to this stream
    const { data: links } = await supabase
      .from('recurring_stream_transactions_table')
      .select('transaction_id')
      .eq('stream_id', stream.id);

    if (!links || links.length === 0) continue;

    const txIds = links.map((l: any) => l.transaction_id);

    // Mark these transactions as recurring
    await supabase
      .from('transactions_table')
      .update({ is_recurring: true })
      .in('id', txIds);
  }
}

async function updateProfileRecurringSummary(supabase: any, userId: string): Promise<void> {
  // Calculate totals from active, non-excluded streams
  const { data: incomeStreams } = await supabase
    .from('recurring_streams_table')
    .select('monthly_amount')
    .eq('user_id', userId)
    .eq('type', 'income')
    .eq('is_active', true)
    .eq('is_excluded', false)
    .or('user_marked_recurring.is.null,user_marked_recurring.eq.true');

  const { data: expenseStreams } = await supabase
    .from('recurring_streams_table')
    .select('monthly_amount')
    .eq('user_id', userId)
    .eq('type', 'expense')
    .eq('is_active', true)
    .eq('is_excluded', false)
    .or('user_marked_recurring.is.null,user_marked_recurring.eq.true');

  const monthlyIncome = incomeStreams?.reduce((sum: number, s: any) => sum + Number(s.monthly_amount), 0) || 0;
  const monthlyExpenses = expenseStreams?.reduce((sum: number, s: any) => sum + Number(s.monthly_amount), 0) || 0;

  await supabase
    .from('profiles_table')
    .update({
      monthly_income: monthlyIncome,
      monthly_mandatory_expenses: monthlyExpenses
    })
    .eq('id', userId);
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
```
