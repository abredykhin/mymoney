## 3.5. Backend: New Edge Function - `create-manual-stream`

Create `/supabase/functions/create-manual-stream/index.ts`:

### Purpose:
- Allow users to manually create recurring streams for transactions Plaid missed
- Generate match pattern from transaction details
- Immediately find and link matching transactions
- Update budget calculations

### Input:
```typescript
{
  transaction_id: number,  // Internal transaction ID
  frequency: 'weekly' | 'bi-weekly' | 'monthly' | 'quarterly' | 'yearly',
  user_id: string
}
```

### Implementation:

```typescript
import { createServiceRoleClient, requireAuth, handleCors, jsonResponse } from '../_shared/auth.ts';

interface CreateManualStreamRequest {
  transaction_id: number;
  frequency: string;
  user_id?: string;
}

Deno.serve(async (req: Request) => {
  // Handle CORS
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const body: CreateManualStreamRequest = await req.json();
    let { transaction_id, frequency, user_id } = body;

    // Get user from auth if not provided
    if (!user_id) {
      const authResult = await requireAuth(req);
      if (authResult instanceof Response) return authResult;
      user_id = authResult.id;
    }

    if (!transaction_id || !frequency) {
      return jsonResponse({ error: 'Missing required parameters' }, 400);
    }

    console.log(`📝 Creating manual stream from transaction ${transaction_id}`);

    const result = await createManualStream(transaction_id, frequency, user_id);

    return jsonResponse(result);
  } catch (error: any) {
    console.error('❌ Create manual stream failed:', error);
    return jsonResponse({ error: error.message }, 500);
  }
});

async function createManualStream(
  transactionId: number,
  frequency: string,
  userId: string
): Promise<any> {
  const supabase = createServiceRoleClient();

  // 1. Fetch the transaction details
  const { data: transaction, error: txError } = await supabase
    .from('transactions_table')
    .select('name, merchant_name, amount, personal_finance_category, account_id')
    .eq('id', transactionId)
    .eq('user_id', userId)
    .single();

  if (txError || !transaction) {
    throw new Error('Transaction not found');
  }

  // 2. Get account details to fetch item_id
  const { data: account } = await supabase
    .from('accounts_table')
    .select('item_id')
    .eq('id', transaction.account_id)
    .single();

  // 3. Determine type based on amount (positive = expense, negative = income)
  const type = transaction.amount > 0 ? 'expense' : 'income';

  // 4. Generate match pattern from merchant name or transaction name
  // MVP: Use the merchant name if available, otherwise extract key part of name
  const matchPattern = extractMatchPattern(transaction);

  console.log(`  Generated match pattern: "${matchPattern}"`);

  // 5. Check if a similar manual stream already exists
  const { data: existingStreams } = await supabase
    .from('recurring_streams_table')
    .select('id, description')
    .eq('user_id', userId)
    .eq('is_manual', true)
    .ilike('match_pattern', `%${matchPattern}%`);

  if (existingStreams && existingStreams.length > 0) {
    return {
      success: false,
      error: 'A manual stream with this pattern already exists',
      existing_stream: existingStreams[0]
    };
  }

  // 6. Calculate monthly amount based on frequency
  const monthlyAmount = calculateMonthlyAmount(Math.abs(transaction.amount), frequency);

  // 7. Create the manual stream
  const streamData = {
    user_id: userId,
    item_id: account?.item_id,
    account_id: transaction.account_id,
    plaid_stream_id: null, // Manual streams don't have Plaid IDs
    description: transaction.merchant_name || transaction.name,
    merchant_name: transaction.merchant_name,
    personal_finance_category: transaction.personal_finance_category || null,  // PRIMARY value
    personal_finance_subcategory: transaction.personal_finance_subcategory || null,  // DETAILED value
    frequency: frequency.toUpperCase(), // Convert to MONTHLY, WEEKLY, etc.
    average_amount: Math.abs(transaction.amount),
    last_amount: Math.abs(transaction.amount),
    monthly_amount: monthlyAmount,
    iso_currency_code: 'USD',
    type: type,
    status: 'MANUAL',
    is_active: true,
    is_user_modified: false,
    first_date: null, // Will be populated by matcher
    last_date: null,
    predicted_next_date: null,
    user_marked_recurring: true, // User explicitly created this
    is_excluded: false,
    is_manual: true,
    match_pattern: matchPattern,
    last_synced_at: new Date().toISOString()
  };

  const { data: newStream, error: insertError } = await supabase
    .from('recurring_streams_table')
    .insert(streamData)
    .select()
    .single();

  if (insertError) {
    throw new Error(`Failed to create stream: ${insertError.message}`);
  }

  console.log(`  ✅ Created manual stream: ${newStream.id}`);

  // 8. Find all matching transactions
  const { data: matchingTransactions } = await supabase
    .from('transactions_table')
    .select('id, date, name, amount')
    .eq('user_id', userId)
    .ilike('name', `%${matchPattern}%`)
    .order('date', { ascending: false });

  console.log(`  Found ${matchingTransactions?.length || 0} matching transactions`);

  if (matchingTransactions && matchingTransactions.length > 0) {
    // 9. Link all matching transactions
    const junctionRecords = matchingTransactions.map((tx: any) => ({
      stream_id: newStream.id,
      transaction_id: tx.id
    }));

    await supabase
      .from('recurring_stream_transactions_table')
      .upsert(junctionRecords, { ignoreDuplicates: true });

    // 10. Update first_date and last_date on the stream
    const dates = matchingTransactions.map((tx: any) => tx.date).sort();
    await supabase
      .from('recurring_streams_table')
      .update({
        first_date: dates[0],
        last_date: dates[dates.length - 1]
      })
      .eq('id', newStream.id);
  }

  // 11. Update transaction recurring flags
  await updateTransactionRecurringFlags(supabase, userId);

  // 12. Update profile summary
  await updateProfileRecurringSummary(supabase, userId);

  return {
    success: true,
    stream: newStream,
    matched_transactions: matchingTransactions?.length || 0
  };
}

function extractMatchPattern(transaction: any): string {
  // MVP: Simple extraction logic
  // Priority: merchant_name > cleaned transaction name
  if (transaction.merchant_name) {
    return transaction.merchant_name.trim();
  }

  // Extract core merchant name from transaction name
  // Common patterns: "MERCHANT NAME 123456", "MERCHANT*LOCATION", "TST* MERCHANT"
  let name = transaction.name.trim();

  // Remove common suffixes (dates, reference numbers)
  name = name.replace(/\s+\d{2}\/\d{2}$/g, ''); // Remove trailing dates
  name = name.replace(/\s+#\d+$/g, ''); // Remove trailing reference numbers

  // Take first meaningful part (before location/store number)
  const parts = name.split(/[\*\s#]/);
  const cleanedName = parts.find((p: string) => p.length >= 3) || parts[0];

  return cleanedName.trim().toUpperCase();
}

function calculateMonthlyAmount(amount: number, frequency: string): number {
  // Convert to uppercase to match Plaid format
  const freq = frequency.toUpperCase();

  const multipliers: Record<string, number> = {
    'WEEKLY': 52 / 12,
    'SEMI_MONTHLY': 2,
    'MONTHLY': 1,
    'QUARTERLY': 1 / 3,
    'ANNUALLY': 1 / 12
  };

  const multiplier = multipliers[freq];

  if (multiplier === undefined) {
    throw new Error(`Unknown frequency: ${frequency}`);
  }

  return amount * multiplier;
}

// Import these functions from sync-recurring-transactions or shared utilities
async function updateTransactionRecurringFlags(supabase: any, userId: string): Promise<void> {
  // Mark all transactions as non-recurring initially
  await supabase
    .from('transactions_table')
    .update({ is_recurring: false })
    .eq('user_id', userId);

  // Fetch all active recurring streams (respecting user overrides)
  const { data: streams } = await supabase
    .from('recurring_streams_table')
    .select('id, user_marked_recurring, is_excluded, status, is_active')
    .eq('user_id', userId)
    .eq('is_active', true);

  for (const stream of streams || []) {
    // CRITICAL: Exclude TOMBSTONED streams (subscriptions that ended) from budget calculations
    const shouldMarkRecurring =
      stream.user_marked_recurring === true ||
      (stream.user_marked_recurring === null &&
       !stream.is_excluded &&
       stream.status !== 'TOMBSTONED' &&  // Don't include ended subscriptions
       stream.is_active === true);

    if (!shouldMarkRecurring) continue;

    const { data: links } = await supabase
      .from('recurring_stream_transactions_table')
      .select('transaction_id')
      .eq('stream_id', stream.id);

    if (!links || links.length === 0) continue;

    const txIds = links.map((l: any) => l.transaction_id);

    await supabase
      .from('transactions_table')
      .update({ is_recurring: true })
      .in('id', txIds);
  }
}

async function updateProfileRecurringSummary(supabase: any, userId: string): Promise<void> {
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
```
