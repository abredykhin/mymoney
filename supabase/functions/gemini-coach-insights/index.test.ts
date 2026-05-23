/**
 * Integration test for gemini-coach-insights
 */

import {
  setupTestEnvironment,
  assertEquals,
  createTestServiceRoleClient,
  createTestSupabaseClient,
} from '../_shared/test-utils.ts';

await setupTestEnvironment();

Deno.test({
  name: 'gemini-coach-insights: returns nudge insights successfully',
  sanitizeResources: false,
  sanitizeOps: false,
  fn: async () => {
    const supabase = createTestServiceRoleClient();
    const testUserId = '00000000-0000-0000-0000-000000888888';

    try {
      // Create test user
      await supabase.auth.admin.createUser({
        id: testUserId,
        email: 'test-coach@example.com',
        password: 'testpassword123',
        email_confirm: true,
      });
    } catch (e: any) {
      if (!e.message?.includes('already')) throw e;
    }

    // Upsert user profile with standard values
    await supabase.from('profiles_table').upsert({
      id: testUserId,
      monthly_income: 10000.00,
      monthly_mandatory_expenses: 4000.00,
    });

    // Create a mock transaction to trigger normal execution paths
    const { data: tx, error: txError } = await supabase
      .from('transactions_table')
      .insert({
        user_id: testUserId,
        transaction_id: 'mock_tx_coach_123',
        amount: 85.50,
        name: 'Whole Foods Market',
        date: new Date().toISOString().split('T')[0],
        personal_finance_category: 'FOOD_AND_DRINK_GROCERIES',
        pending: false,
        payment_channel: 'in store',
      })
      .select()
      .single();

    if (txError) throw txError;

    // Sign in to local Supabase to get a real valid session token
    const anonClient = createTestSupabaseClient();
    const { data: sessionData, error: signInError } = await anonClient.auth.signInWithPassword({
      email: 'test-coach@example.com',
      password: 'testpassword123',
    });

    if (signInError) throw signInError;
    const sessionToken = sessionData.session?.access_token;
    if (!sessionToken) throw new Error('Failed to retrieve session token');

    // Call gemini-coach-insights
    const response = await fetch('http://127.0.0.1:54321/functions/v1/gemini-coach-insights', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${sessionToken}`,
      },
    });

    const result = await response.json();
    console.log('Gemini Coach Insights response:', result);

    // Teardown / Cleanup
    await supabase.from('transactions_table').delete().eq('user_id', testUserId);
    await supabase.from('profiles_table').delete().eq('id', testUserId);
    await supabase.auth.admin.deleteUser(testUserId);

    // Assertions
    assertEquals(response.status, 200);
    assertEquals(typeof result.badge, 'string');
    assertEquals(typeof result.headline, 'string');
    assertEquals(typeof result.nudge_text, 'string');
    assertEquals(typeof result.action_label, 'string');
    assertEquals(typeof result.alternative_tip, 'string');
  },
});
