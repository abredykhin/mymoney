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

    // Call gemini-coach-insights (First call: miss and generate/cache)
    const response = await fetch('http://127.0.0.1:54321/functions/v1/gemini-coach-insights', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${sessionToken}`,
      },
    });

    const result = await response.json();
    console.log('Gemini Coach Insights response:', result);

    // Verify cache was populated in the database
    const { data: cachedRows, error: cacheFetchError } = await supabase
      .from('coach_insights')
      .select('*')
      .eq('user_id', testUserId);
    
    if (cacheFetchError) throw cacheFetchError;

    // Call gemini-coach-insights a second time (Second call: hit cache)
    const response2 = await fetch('http://127.0.0.1:54321/functions/v1/gemini-coach-insights', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${sessionToken}`,
      },
      body: JSON.stringify({ force: false }),
    });

    const result2 = await response2.json();
    console.log('Gemini Coach Insights cached response:', result2);

    // Call gemini-coach-insights a third time (Third call: force refresh bypass cache)
    const response3 = await fetch('http://127.0.0.1:54321/functions/v1/gemini-coach-insights', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${sessionToken}`,
      },
      body: JSON.stringify({ force: true }),
    });

    const result3 = await response3.json();
    console.log('Gemini Coach Insights force-refreshed response:', result3);

    // Teardown / Cleanup
    await supabase.from('coach_insights').delete().eq('user_id', testUserId);
    await supabase.from('transactions_table').delete().eq('user_id', testUserId);
    await supabase.from('profiles_table').delete().eq('id', testUserId);
    await supabase.auth.admin.deleteUser(testUserId);

    // Assertions
    assertEquals(response.status, 200);
    assertEquals(response2.status, 200);
    assertEquals(response3.status, 200);

    assertEquals(cachedRows?.length, 1);
    assertEquals(cachedRows?.[0].badge, result.badge);
    assertEquals(cachedRows?.[0].headline, result.headline);

    assertEquals(result2.headline, result.headline);
    assertEquals(result3.headline, result.headline);
  },
});
