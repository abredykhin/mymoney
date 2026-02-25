/**
 * Shared test utilities for Edge Functions
 *
 * IMPORTANT: Tests run against LOCAL Supabase instance, not mocks.
 * Start local Supabase with: supabase start
 */

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { load } from "https://deno.land/std@0.224.0/dotenv/mod.ts";

// Load test environment variables
let envLoaded = false;

/**
 * Loads test environment variables from .env.local file
 * Call this at the beginning of EVERY test file
 *
 * @example
 * ```typescript
 * import { setupTestEnvironment } from '../_shared/test-utils.ts';
 * await setupTestEnvironment();
 * ```
 */
export async function setupTestEnvironment() {
  if (!envLoaded) {
    try {
      await load({
        envPath: new URL("../.env.local", import.meta.url).pathname,
        export: true,
      });
      envLoaded = true;
    } catch (error) {
      console.warn("Warning: Could not load .env.local file:", (error as Error).message);
      console.warn("Tests will use system environment variables");
    }
  }
}

/**
 * Creates a REAL Supabase client pointing to local instance
 * Use this for authenticated user operations
 *
 * @returns Real SupabaseClient (NOT A MOCK)
 */
export function createTestSupabaseClient(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL') || Deno.env.get('CUSTOM_SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_ANON_KEY') || Deno.env.get('CUSTOM_ANON_KEY');

  if (!url || !key) {
    throw new Error('SUPABASE_URL and SUPABASE_ANON_KEY must be set. Run setupTestEnvironment() first.');
  }

  return createClient(url, key);
}

/**
 * Creates a REAL Supabase client with service role (bypasses RLS)
 * Use this for test setup/teardown that needs to bypass RLS
 *
 * @returns Real SupabaseClient with service role (NOT A MOCK)
 */
export function createTestServiceRoleClient(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL') || Deno.env.get('CUSTOM_SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('CUSTOM_SERVICE_ROLE_KEY');

  if (!url || !key) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY must be set. Run setupTestEnvironment() first.');
  }

  return createClient(url, key);
}

/**
 * Generates a REAL JWT token for testing authenticated requests
 * This creates a valid JWT that will be accepted by local Supabase
 *
 * @param options - JWT configuration
 * @returns Bearer token string (e.g., "Bearer eyJh...")
 */
export async function createTestJWT(options: {
  userId?: string;
  role?: string;
  expiresIn?: number;
} = {}): Promise<string> {
  const {
    userId = 'test-user-id',
    role = 'authenticated',
    expiresIn = 3600,
  } = options;

  const { create } = await import("https://deno.land/x/djwt@v2.8/mod.ts");

  const secret = Deno.env.get('SUPABASE_JWT_SECRET');
  if (!secret) {
    throw new Error('SUPABASE_JWT_SECRET must be set. Run setupTestEnvironment() first.');
  }

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const now = Math.floor(Date.now() / 1000);

  const jwt = await create(
    { alg: "HS256", typ: "JWT" },
    {
      sub: userId,
      role: role,
      aud: "authenticated",
      exp: now + expiresIn,
      iat: now,
    },
    key
  );

  return `Bearer ${jwt}`;
}

/**
 * Helper to manage test data lifecycle: setup → test → cleanup
 * Ensures cleanup runs even if test fails
 *
 * @example
 * ```typescript
 * await withTestData(
 *   // Setup: create test data
 *   async () => {
 *     const supabase = createTestServiceRoleClient();
 *     const { data } = await supabase.from('items').insert({...}).select().single();
 *     return data;
 *   },
 *   // Cleanup: delete test data
 *   async (data) => {
 *     const supabase = createTestServiceRoleClient();
 *     await supabase.from('items').delete().eq('id', data.id);
 *   },
 *   // Test: verify behavior
 *   async (data) => {
 *     assertEquals(data.field, expectedValue);
 *   }
 * );
 * ```
 */
export async function withTestData<T>(
  setup: () => Promise<T>,
  cleanup: (data: T) => Promise<void>,
  test: (data: T) => Promise<void>
): Promise<void> {
  const data = await setup();
  try {
    await test(data);
  } finally {
    try {
      await cleanup(data);
    } catch (cleanupError) {
      console.error('Cleanup error:', cleanupError);
      // Don't throw - we want test failure, not cleanup failure
    }
  }
}

/**
 * Creates a REAL Plaid client configured for sandbox testing
 *
 * ⚠️ IMPORTANT: This uses REAL Plaid sandbox (sandbox.plaid.com), NOT mocks
 *
 * Plaid provides a free sandbox environment with:
 * - Rich test data
 * - Deterministic behavior
 * - Test institutions (use "ins_109508" for First Platypus Bank)
 * - Default credentials: user_good / pass_good
 *
 * Patterns inspired by Plaid AI Coding Toolkit:
 * https://github.com/plaid/ai-coding-toolkit/tree/main/sandbox
 *
 * Official docs: https://plaid.com/docs/sandbox/
 *
 * @returns Real PlaidApi instance pointed at sandbox
 */
export async function createTestPlaidClient() {
  const { PlaidApi, PlaidEnvironments, Configuration } = await import('npm:plaid@31.1.0');

  const clientId = Deno.env.get('PLAID_CLIENT_ID');
  const secret = Deno.env.get('PLAID_SECRET');

  if (!clientId || !secret) {
    throw new Error('PLAID_CLIENT_ID and PLAID_SECRET must be set in .env.local');
  }

  const configuration = new Configuration({
    basePath: PlaidEnvironments.sandbox,
    baseOptions: {
      headers: {
        'PLAID-CLIENT-ID': clientId,
        'PLAID-SECRET': secret,
      },
    },
  });

  return new PlaidApi(configuration);
}

/**
 * Creates a test Item in Plaid sandbox without going through Link flow
 *
 * This bypasses the UI flow and directly creates an Item with mocked data.
 * Uses Plaid's /sandbox/public_token/create endpoint.
 *
 * Pattern from Plaid AI Coding Toolkit - provides working access token + item ID.
 *
 * @param options - Test item configuration
 * @returns Object with public_token, item_id, and access_token (after exchange)
 *
 * @example
 * ```typescript
 * // Create item and exchange for access token (all sandbox)
 * const { access_token, item_id } = await createTestPlaidItem();
 *
 * // Now use access_token for testing transactions, accounts, etc.
 * const { data } = await plaid.accountsGet({ access_token });
 * ```
 */
export async function createTestPlaidItem(options: {
  institutionId?: string;
  initialProducts?: Array<'transactions' | 'auth' | 'identity' | 'assets' | 'investments' | 'liabilities' | 'payment_initiation'>;
  testCredentials?: 'good' | 'bad' | 'locked';
} = {}) {
  console.log('📍 createTestPlaidItem called');
  const plaid = await createTestPlaidClient();

  const {
    institutionId = 'ins_109508', // First Platypus Bank (test institution)
    initialProducts = ['transactions' as any], // Cast to any to satisfy Plaid SDK types
    testCredentials = 'good', // user_good / user_bad / user_locked
  } = options;

  console.log('📍 Plaid config:', { institutionId, initialProducts, testCredentials });

  // Create public token in sandbox
  let createResponse;
  try {
    const { Products } = await import('npm:plaid@31.1.0');
    const webhookUrl = Deno.env.get('PLAID_WEBHOOK_URL') || 'http://127.0.0.1:54321/functions/v1/plaid-webhook';

    createResponse = await plaid.sandboxPublicTokenCreate({
      institution_id: institutionId,
      initial_products: [Products.Transactions],  // Use Products enum
      options: {
        override_username: `user_${testCredentials}`,
        override_password: `pass_${testCredentials}`,
        webhook: webhookUrl,  // Configure webhook URL for sandbox item
      },
    });
  } catch (error: any) {
    console.error('❌ Plaid sandbox token creation failed');
    console.error('Error:', error.message);
    if (error.response?.data) {
      console.error('Plaid API error:', JSON.stringify(error.response.data, null, 2));
    }
    throw error;
  }

  const public_token = createResponse.data.public_token;
  console.log('✅ Got public token:', public_token.substring(0, 20) + '...');

  // Exchange for access token
  console.log('📍 Exchanging for access token...');
  const exchangeResponse = await plaid.itemPublicTokenExchange({
    public_token: public_token,
  });

  console.log('✅ Got access token');
  return {
    public_token: public_token,
    access_token: exchangeResponse.data.access_token,
    item_id: exchangeResponse.data.item_id,
    institution_id: institutionId,
  };
}

/**
 * Simulates a Plaid webhook event in the sandbox environment
 *
 * Uses /sandbox/item/fire_webhook to trigger webhook events.
 * Pattern from Plaid AI Coding Toolkit: https://github.com/plaid/ai-coding-toolkit/tree/main/sandbox
 *
 * This allows testing webhook handling without waiting for real events.
 * The webhook will be sent to the PLAID_WEBHOOK_URL configured in .env.local.
 *
 * @param accessToken - Plaid access token for the item
 * @param webhookCode - Type of webhook to simulate
 *
 * @example
 * ```typescript
 * // Simulate new transactions available
 * await triggerPlaidSandboxWebhook(access_token, 'SYNC_UPDATES_AVAILABLE');
 *
 * // Simulate recurring transactions detected
 * await triggerPlaidSandboxWebhook(access_token, 'RECURRING_TRANSACTIONS_UPDATE');
 * ```
 */
export async function triggerPlaidSandboxWebhook(
  accessToken: string,
  webhookCode: string = 'DEFAULT_UPDATE'
) {
  const plaid = await createTestPlaidClient();

  // Cast to any to bypass strict enum checking for sandbox flexibility
  await plaid.sandboxItemFireWebhook({
    access_token: accessToken,
    webhook_code: webhookCode as any,
    webhook_type: 'TRANSACTIONS' as any,  // Required for DEFAULT_UPDATE
  });

  console.log(`✅ Triggered webhook: ${webhookCode}`);
}

/**
 * Resets Plaid sandbox item login (useful for testing error states)
 *
 * @param accessToken - Plaid access token
 */
export async function resetPlaidSandboxItem(accessToken: string) {
  const plaid = await createTestPlaidClient();

  await plaid.sandboxItemResetLogin({
    access_token: accessToken,
  });
}

/**
 * Test helper: Create a Plaid item and trigger a webhook in one call
 *
 * Simplifies webhook testing by combining item creation and webhook triggering.
 * Pattern inspired by Plaid AI Coding Toolkit.
 *
 * @param webhookCode - Type of webhook to trigger after item creation
 * @returns Object with access_token, item_id, and webhook trigger confirmation
 *
 * @example
 * ```typescript
 * // Create item and simulate new transactions webhook
 * const { access_token, item_id } = await createItemAndTriggerWebhook('SYNC_UPDATES_AVAILABLE');
 *
 * // Now verify your webhook handler processed it correctly
 * const { data: transactions } = await supabase
 *   .from('transactions_table')
 *   .select('*')
 *   .eq('plaid_item_id', item_id);
 * ```
 */
export async function createItemAndTriggerWebhook(
  webhookCode: Parameters<typeof triggerPlaidSandboxWebhook>[1] = 'DEFAULT_UPDATE'
) {
  // Create test item
  const item = await createTestPlaidItem();

  // Give Plaid a moment to process the item creation
  await new Promise(resolve => setTimeout(resolve, 100));

  // Trigger webhook
  await triggerPlaidSandboxWebhook(item.access_token, webhookCode);

  return item;
}

// Re-export standard assertions for convenience
export {
  assertEquals,
  assertExists,
  assertRejects,
  assertStrictEquals,
  assertThrows,
  assertNotEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

// Re-export FakeTime for testing time-dependent code
export { FakeTime } from "https://deno.land/std@0.224.0/testing/time.ts";
