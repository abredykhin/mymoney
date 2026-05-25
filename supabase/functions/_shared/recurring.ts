import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * Update is_recurring flag on all transactions based on recurring streams
 */
export async function updateTransactionRecurringFlags(
  supabase: SupabaseClient,
  userId: string
): Promise<void> {
  console.log('📍 Updating transaction recurring flags');

  // Reset all to false first
  await supabase
    .from('transactions_table')
    .update({ is_recurring: false })
    .eq('user_id', userId);

  // Get all active streams (excluding TOMBSTONED)
  const { data: streams } = await supabase
    .from('recurring_streams_table')
    .select('id, user_marked_recurring, is_excluded, status, is_active')
    .eq('user_id', userId)
    .eq('is_active', true);

  for (const stream of streams || []) {
    const shouldMarkRecurring =
      stream.user_marked_recurring === true ||
      (stream.user_marked_recurring === null &&
       !stream.is_excluded &&
       stream.status !== 'TOMBSTONED' &&
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

  console.log('✅ Transaction recurring flags updated');
}

/**
 * Calculate and update profile's recurring income/expenses summary
 */
export async function updateProfileRecurringSummary(
  supabase: SupabaseClient,
  userId: string
): Promise<void> {
  console.log('📍 Updating profile recurring summary');

  // Get DB-filtered mandatory expense streams. The view owns de-dupe rules
  // such as suppressing manual rent when Plaid has detected the same rent.
  const { data: expenseStreams } = await supabase
    .from('active_mandatory_expense_streams')
    .select('type, monthly_amount, user_marked_recurring, is_excluded, status')
    .eq('user_id', userId);

  const { data: incomeStreams } = await supabase
    .from('recurring_streams_table')
    .select('type, monthly_amount, user_marked_recurring, is_excluded, status')
    .eq('user_id', userId)
    .eq('type', 'income')
    .eq('is_active', true)
    .neq('status', 'TOMBSTONED');

  let monthlyIncome = 0;
  let monthlyExpenses = 0;

  for (const stream of [...(expenseStreams || []), ...(incomeStreams || [])]) {
    const shouldInclude =
      stream.user_marked_recurring === true ||
      (stream.user_marked_recurring === null && !stream.is_excluded);

    if (!shouldInclude) continue;

    if (stream.type === 'income') {
      monthlyIncome += parseFloat(stream.monthly_amount);
    } else if (stream.type === 'expense') {
      monthlyExpenses += parseFloat(stream.monthly_amount);
    }
  }

  // Only overwrite income when Plaid detected recurring streams.
  // If the sum is 0 (bank just linked, streams not detected yet), preserve
  // whatever the user entered during onboarding.
  const profileUpdate: Record<string, unknown> = {
    monthly_mandatory_expenses: monthlyExpenses,
    updated_at: new Date().toISOString()
  };
  if (monthlyIncome > 0) {
    profileUpdate.monthly_income = monthlyIncome;
  }

  await supabase
    .from('profiles_table')
    .update(profileUpdate)
    .eq('id', userId);

  console.log(`✅ Profile updated: income=${monthlyIncome > 0 ? monthlyIncome : '(preserved)' }, expenses=${monthlyExpenses}`);
}
