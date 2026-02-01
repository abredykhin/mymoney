### 6.3 Code Organization: Shared Utilities

**CRITICAL:** The functions `updateTransactionRecurringFlags` and `updateProfileRecurringSummary` are duplicated across multiple edge functions. These should be extracted to `/supabase/functions/_shared/recurring.ts` for reusability and maintainability.

**Create `/supabase/functions/_shared/recurring.ts`:**

```typescript
import { createClient, SupabaseClient } from '@supabase/supabase-js';

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

  // Get all active, non-excluded streams (excluding TOMBSTONED)
  const { data: streams } = await supabase
    .from('recurring_streams_table')
    .select('type, monthly_amount, user_marked_recurring, is_excluded, status')
    .eq('user_id', userId)
    .eq('is_active', true)
    .neq('status', 'TOMBSTONED');  // Critical: Don't include ended subscriptions

  let monthlyIncome = 0;
  let monthlyExpenses = 0;

  for (const stream of streams || []) {
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

  await supabase
    .from('profiles_table')
    .update({
      monthly_income: monthlyIncome,
      monthly_mandatory_expenses: monthlyExpenses,
      updated_at: new Date().toISOString()
    })
    .eq('id', userId);

  console.log(`✅ Profile updated: income=${monthlyIncome}, expenses=${monthlyExpenses}`);
}
```

**Update all edge functions to import from shared:**

```typescript
// In sync-recurring-transactions/index.ts
import { updateTransactionRecurringFlags, updateProfileRecurringSummary } from '../_shared/recurring.ts';

// In create-manual-stream/index.ts
import { updateTransactionRecurringFlags, updateProfileRecurringSummary } from '../_shared/recurring.ts';

// Remove duplicate function definitions from both files
```
