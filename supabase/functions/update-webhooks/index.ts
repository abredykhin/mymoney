/**
 * Supabase Edge Function: update-webhooks
 *
 * Updates webhook URLs for all active Plaid items using the /item/webhook/update endpoint.
 * This is needed when changing the webhook URL configuration.
 *
 * IMPORTANT: This should be called with service role key as it accesses all users' items.
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { createPlaidClient, PLAID_WEBHOOK_URL } from '../_shared/plaid.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface UpdateResult {
  item_id: number;
  plaid_item_id: string;
  success: boolean;
  error?: string;
}

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('🔧 Starting webhook URL update for all items...');
    console.log(`📍 Target webhook URL: ${PLAID_WEBHOOK_URL}`);

    // Verify service role authentication
    const authHeader = req.headers.get('Authorization');
    const serviceRoleKey = Deno.env.get('CUSTOM_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!authHeader || !authHeader.includes(serviceRoleKey!)) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized - Service role key required' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Create Supabase admin client
    const supabaseUrl = Deno.env.get('CUSTOM_SUPABASE_URL') || Deno.env.get('SUPABASE_URL')!;
    const supabase = createClient(supabaseUrl, serviceRoleKey!);

    // Fetch all active items
    const { data: items, error: fetchError } = await supabase
      .from('items_table')
      .select('id, plaid_item_id, plaid_access_token, user_id, bank_name')
      .eq('is_active', true);

    if (fetchError) {
      console.error('❌ Error fetching items:', fetchError);
      throw fetchError;
    }

    if (!items || items.length === 0) {
      console.log('ℹ️  No active items found');
      return new Response(
        JSON.stringify({ message: 'No active items to update', updated: 0 }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`📦 Found ${items.length} active items to update`);

    // Initialize Plaid client
    const plaidClient = createPlaidClient();

    // Update each item
    const results: UpdateResult[] = [];

    for (const item of items) {
      console.log(`\n🔄 Updating item ${item.id} (${item.bank_name}) for user ${item.user_id}...`);
      console.log(`   Plaid item ID: ${item.plaid_item_id}`);

      try {
        // Call Plaid's webhook update endpoint
        const response = await plaidClient.itemWebhookUpdate({
          access_token: item.plaid_access_token,
          webhook: PLAID_WEBHOOK_URL,
        });

        console.log(`✅ Successfully updated webhook for item ${item.id}`);
        console.log(`   New webhook: ${response.data.item.webhook}`);

        results.push({
          item_id: item.id,
          plaid_item_id: item.plaid_item_id,
          success: true,
        });
      } catch (error: any) {
        console.error(`❌ Failed to update item ${item.id}:`, error.message);

        results.push({
          item_id: item.id,
          plaid_item_id: item.plaid_item_id,
          success: false,
          error: error.message || 'Unknown error',
        });
      }
    }

    // Summary
    const successful = results.filter(r => r.success).length;
    const failed = results.filter(r => !r.success).length;

    console.log(`\n📊 Update Summary:`);
    console.log(`   ✅ Successful: ${successful}`);
    console.log(`   ❌ Failed: ${failed}`);
    console.log(`   📍 Webhook URL: ${PLAID_WEBHOOK_URL}`);

    return new Response(
      JSON.stringify({
        message: 'Webhook update completed',
        webhook_url: PLAID_WEBHOOK_URL,
        total: items.length,
        successful,
        failed,
        results,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );

  } catch (error: any) {
    console.error('❌ Error in update-webhooks function:', error);
    return new Response(
      JSON.stringify({
        error: error.message || 'Internal server error',
        details: error.toString(),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

/**
 * USAGE:
 *
 * Deploy:
 *   $ supabase functions deploy update-webhooks
 *
 * Run (requires service role key):
 *   $ curl -X POST 'https://teuyzmreoyganejfvquk.supabase.co/functions/v1/update-webhooks' \
 *     -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY"
 *
 * Or use the Supabase client in your app:
 *   ```swift
 *   let response = try await supabase.functions.invoke(
 *     "update-webhooks",
 *     options: FunctionInvokeOptions(
 *       headers: ["Authorization": "Bearer \(serviceRoleKey)"]
 *     )
 *   )
 *   ```
 */
