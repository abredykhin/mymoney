/**
 * Integration test for sync-transactions
 *
 * Quick test to verify edge function can access database with fixed auth.ts
 */

import {
  setupTestEnvironment,
  assertEquals,
  createTestServiceRoleClient,
  createTestPlaidItem,
  triggerPlaidSandboxWebhook,
} from '../_shared/test-utils.ts';

await setupTestEnvironment();

Deno.test({
  name: 'sync-transactions: edge function can access database',
  sanitizeResources: false,
  sanitizeOps: false,
  fn: async () => {
  const supabase = createTestServiceRoleClient();
  const testUserId = '00000000-0000-0000-0000-000000999999';

  try {
    // Create test user
    await supabase.auth.admin.createUser({
      id: testUserId,
      email: 'test-db-access@example.com',
      password: 'test123',
      email_confirm: true,
    });
  } catch (e: any) {
    if (!e.message?.includes('already')) throw e;
  }

  await supabase.from('profiles_table').upsert({
    id: testUserId,
    username: 'test-db-access',
  });

  // Create Plaid item
  const { access_token, item_id, institution_id } = await createTestPlaidItem();

  // Insert item into DB
  const { data: item, error } = await supabase
    .from('items_table')
    .insert({
      user_id: testUserId,
      plaid_item_id: item_id,
      plaid_access_token: access_token,
      plaid_institution_id: institution_id,
      bank_name: 'Test Bank',
      status: 'ACTIVE',
    })
    .select()
    .single();

  if (error) throw error;

  // Trigger webhook
  await triggerPlaidSandboxWebhook(access_token, 'DEFAULT_UPDATE');
  await new Promise(r => setTimeout(r, 1000));

  // Call sync-transactions
  const response = await fetch('http://127.0.0.1:54321/functions/v1/sync-transactions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
    },
    body: JSON.stringify({ plaid_item_id: item_id }),
  });

  const result = await response.json();
  console.log('Response:', result);

  // Cleanup
  await supabase.from('transactions_table').delete().eq('user_id', testUserId);
  await supabase.from('accounts_table').delete().eq('item_id', item.id);
  await supabase.from('items_table').delete().eq('id', item.id);
  await supabase.from('profiles_table').delete().eq('id', testUserId);

  // Assert
  assertEquals(response.status, 200);
  assertEquals(result.success, true);
  console.log(`✅ Synced ${result.added} transactions successfully!`);
  },
});
