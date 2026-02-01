/**
 * Supabase Edge Function: plaid-webhook
 *
 * Handles incoming webhooks from Plaid for transaction updates and item events.
 *
 * Phase 3.2 - Migrated from server/routes/webhook.js
 *
 * IMPORTANT: This function returns 200 OK immediately and processes webhooks
 * in the background using ctx.waitUntil() to avoid timeout issues.
 */

import { createServiceRoleClient } from '../_shared/auth.ts';
import { validateWebhookSignature } from '../_shared/plaid.ts';

// Webhook event types
interface PlaidWebhookBody {
  webhook_type: 'TRANSACTIONS' | 'ITEM' | 'AUTH' | 'ASSETS' | string;
  webhook_code: string;
  item_id: string;
  error?: {
    error_code: string;
    error_message: string;
  };
  new_transactions?: number;
  removed_transactions?: string[];
  historical_update_complete?: boolean; // Critical for recurring sync timing
  initial_update_complete?: boolean;
  account_ids?: string[]; // NEW: For RECURRING_TRANSACTIONS_UPDATE webhook
  environment: string; // "production" or "sandbox"
}

/**
 * Main webhook handler
 */
Deno.serve(async (req, ctx) => {
  console.log('🔔 Incoming Plaid webhook');

  // Only accept POST requests
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    // Check if running in local development mode
    const isLocal = Deno.env.get('IS_LOCAL_DEV') === 'true';

    // Read body as text first for signature verification
    const bodyText = await req.text();

    // Verify webhook signature (skip in local dev)
    if (!isLocal) {
      console.log('🔐 Verifying webhook signature...');
      const isValid = await validateWebhookSignature(req, bodyText);

      if (!isValid) {
        console.error('❌ Webhook signature verification failed');
        // Return 401 for invalid signatures to alert us of potential attacks
        return new Response(JSON.stringify({
          status: 'error',
          message: 'Invalid webhook signature'
        }), {
          status: 401,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      console.log('✅ Webhook signature verified');
    } else {
      console.log('⚠️  Local dev mode - webhook signature verification skipped');
    }

    // Parse webhook body
    const body: PlaidWebhookBody = JSON.parse(bodyText);
    console.log(`📦 Webhook type: ${body.webhook_type}, code: ${body.webhook_code}`);
    console.log(`📦 Full webhook body:`, JSON.stringify(body));

    // Return 200 OK immediately (Plaid requirement)
    // Process webhook in background with waitUntil
    // Note: waitUntil is not available in local dev, falls back to async processing
    if (ctx && typeof ctx.waitUntil === 'function') {
      ctx.waitUntil(processWebhook(body));
    } else {
      // Local development - process asynchronously without waitUntil
      processWebhook(body).catch((err) => {
        console.error('❌ Background processing error:', err);
      });
    }

    return new Response(JSON.stringify({ status: 'received' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('❌ Error parsing webhook:', error);

    // Still return 200 to avoid Plaid retries for invalid payloads
    return new Response(JSON.stringify({ status: 'error', message: 'Invalid payload' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});

/**
 * Process webhook in background (doesn't block response)
 */
async function processWebhook(body: PlaidWebhookBody) {
  try {
    const { webhook_type, webhook_code } = body;

    switch (webhook_type) {
      case 'TRANSACTIONS':
        await handleTransactionWebhook(webhook_code, body);
        break;
      case 'ITEM':
        await handleItemWebhook(webhook_code, body);
        break;
      default:
        console.log(`ℹ️  Unhandled webhook type: ${webhook_type}`);
    }
  } catch (error) {
    console.error('❌ Error processing webhook:', error);
    // Don't throw - we already returned 200 OK to Plaid
  }
}

/**
 * Handle TRANSACTIONS webhook events
 */
async function handleTransactionWebhook(code: string, body: PlaidWebhookBody) {
  console.log(`📊 Processing transaction webhook: ${code}`);

  switch (code) {
    case 'SYNC_UPDATES_AVAILABLE':
      console.log(`🔄 Sync updates available for item ${body.item_id}`);
      console.log(`   New transactions: ${body.new_transactions || 0}`);
      console.log(`   Historical complete: ${body.historical_update_complete || false}`);

      // Trigger transaction sync
      await triggerTransactionSync(body.item_id, body.historical_update_complete || false);
      break;

    case 'RECURRING_TRANSACTIONS_UPDATE':
      // NEW: Handle recurring transaction pattern updates from Plaid
      console.log(`🔁 Recurring transactions updated for item ${body.item_id}`);
      if (body.account_ids) {
        console.log(`   Affected accounts: ${body.account_ids.join(', ')}`);
      }

      // Only trigger if historical sync is complete
      const canSyncRecurring = await checkHistoricalSyncComplete(body.item_id);
      if (canSyncRecurring) {
        await triggerRecurringSync(body.item_id);
      } else {
        console.log(`   ⚠️ Skipping recurring sync - historical data not yet complete`);
      }
      break;

    case 'DEFAULT_UPDATE':
    case 'INITIAL_UPDATE':
    case 'HISTORICAL_UPDATE':
      // These are deprecated when using transactions/sync endpoint
      console.log(`ℹ️  Ignoring deprecated transaction webhook: ${code}`);
      break;

    default:
      console.log(`⚠️  Unhandled transaction webhook code: ${code}`);
  }
}

/**
 * Handle ITEM webhook events
 */
async function handleItemWebhook(code: string, body: PlaidWebhookBody) {
  console.log(`🏦 Processing item webhook: ${code}`);

  switch (code) {
    case 'ERROR':
      console.error(`❌ Item error for ${body.item_id}:`);
      console.error(`   ${body.error?.error_message || 'Unknown error'}`);
      console.error(`   → User should reconnect their bank account`);

      // TODO: In the future, notify user to reconnect their account
      // For now, just log it
      break;

    case 'LOGIN_REPAIRED':
      console.log(`✅ Login repaired for item ${body.item_id}`);
      console.log(`   → Account is ready to sync again`);
      break;

    case 'NEW_ACCOUNTS_AVAILABLE':
      console.log(`🆕 New accounts available for item ${body.item_id}`);
      console.log(`   → User can be prompted to link additional accounts`);

      // TODO: Notify user about new accounts
      break;

    case 'PENDING_EXPIRATION':
    case 'PENDING_DISCONNECT':
      console.warn(`⏰ Item ${body.item_id} is pending expiration/disconnect`);
      console.warn(`   → User should reconnect their bank account soon`);

      // TODO: Notify user to reconnect before service disruption
      break;

    case 'USER_PERMISSION_REVOKED':
    case 'USER_ACCOUNT_REVOKED':
      console.warn(`🚫 User revoked access to item ${body.item_id}`);
      console.warn(`   → Should remove this item from our records`);

      // TODO: Mark item as revoked in database
      break;

    case 'WEBHOOK_UPDATE_ACKNOWLEDGED':
      console.log(`✅ Webhook URL update acknowledged`);
      break;

    default:
      console.log(`⚠️  Unhandled item webhook code: ${code}`);
  }
}

/**
 * Check if historical sync is complete for an item
 */
async function checkHistoricalSyncComplete(plaidItemId: string): Promise<boolean> {
  try {
    const supabase = createServiceRoleClient();

    const { data: item, error } = await supabase
      .from('items_table')
      .select('historical_sync_complete')
      .eq('plaid_item_id', plaidItemId)
      .single();

    if (error || !item) {
      console.error(`❌ Failed to check historical sync status: ${error?.message}`);
      return false;
    }

    return item.historical_sync_complete === true;
  } catch (error) {
    console.error(`❌ Error checking historical sync status:`, error);
    return false;
  }
}

/**
 * Trigger recurring transaction sync
 */
async function triggerRecurringSync(plaidItemId: string) {
  try {
    console.log(`🔁 Triggering recurring sync for item: ${plaidItemId}`);

    const supabaseUrl = Deno.env.get('CUSTOM_SUPABASE_URL') || Deno.env.get('SUPABASE_URL');
    const functionUrl = supabaseUrl
      ? `${supabaseUrl}/functions/v1/sync-recurring-transactions`
      : 'http://localhost:54321/functions/v1/sync-recurring-transactions';

    const serviceRoleKey = Deno.env.get('CUSTOM_SERVICE_ROLE_KEY') ||
                          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    // Get user_id for this item
    const supabase = createServiceRoleClient();
    const { data: item } = await supabase
      .from('items_table')
      .select('user_id')
      .eq('plaid_item_id', plaidItemId)
      .single();

    if (!item) {
      console.error(`❌ Item not found: ${plaidItemId}`);
      return;
    }

    await fetch(functionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({
        plaid_item_id: plaidItemId,
        user_id: item.user_id
      }),
    });

    console.log(`✅ Recurring sync triggered for item ${plaidItemId}`);
  } catch (error) {
    console.error(`❌ Error triggering recurring sync:`, error);
  }
}

/**
 * Trigger transaction sync by calling the sync-transactions function
 */
async function triggerTransactionSync(plaidItemId: string, historicalComplete: boolean) {
  try {
    console.log(`🚀 Triggering sync for item: ${plaidItemId}`);
    console.log(`📦 Historical complete: ${historicalComplete}`);

    // Get the function URL (either local or production)
    const supabaseUrl = Deno.env.get('CUSTOM_SUPABASE_URL') || Deno.env.get('SUPABASE_URL');
    const functionUrl = supabaseUrl
      ? `${supabaseUrl}/functions/v1/sync-transactions`
      : 'http://localhost:54321/functions/v1/sync-transactions';

    const serviceRoleKey = Deno.env.get('CUSTOM_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    const payload = { 
      plaid_item_id: plaidItemId,
      historical_complete: historicalComplete // Pass this flag to sync-transactions
    };
    console.log(`📤 Sending payload:`, JSON.stringify(payload));

    // Call the sync function with service role key
    const response = await fetch(functionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ Sync trigger failed: ${response.status} - ${errorText}`);
    } else {
      console.log(`✅ Sync triggered successfully for item ${plaidItemId}`);
    }
  } catch (error) {
    console.error(`❌ Error triggering sync:`, error);
  }
}

/**
 * DEPLOYMENT & TESTING
 *
 * Deploy:
 *   $ cd supabase
 *   $ supabase functions deploy plaid-webhook
 *
 * Set secrets (if not already set):
 *   $ supabase secrets set PLAID_CLIENT_ID=your_client_id
 *   $ supabase secrets set PLAID_SECRET=your_secret
 *   $ supabase secrets set PLAID_ENV=sandbox
 *
 * Test locally:
 *   $ supabase functions serve plaid-webhook
 *
 * Test with curl (local):
 *   ```bash
 *   curl -X POST 'http://localhost:54321/functions/v1/plaid-webhook' \
 *     -H "Content-Type: application/json" \
 *     -d '{
 *       "webhook_type": "TRANSACTIONS",
 *       "webhook_code": "SYNC_UPDATES_AVAILABLE",
 *       "item_id": "test-item-123",
 *       "new_transactions": 5
 *     }'
 *   ```
 *
 * Test ITEM webhook:
 *   ```bash
 *   curl -X POST 'http://localhost:54321/functions/v1/plaid-webhook' \
 *     -H "Content-Type: application/json" \
 *     -d '{
 *       "webhook_type": "ITEM",
 *       "webhook_code": "ERROR",
 *       "item_id": "test-item-123",
 *       "error": {
 *         "error_code": "ITEM_LOGIN_REQUIRED",
 *         "error_message": "User credentials required"
 *       }
 *     }'
 *   ```
 *
 * Configure Plaid webhook URL:
 *   - In Plaid Dashboard, set webhook URL to:
 *     https://[your-project-ref].supabase.co/functions/v1/plaid-webhook
 *   - Or set PLAID_WEBHOOK_URL environment variable
 *
 * KEY DIFFERENCES FROM LEGACY:
 *
 * Legacy (Node.js):
 * - Synchronous processing in request handler
 * - Returns after sync completes (slow)
 * - Uses Winston logger
 *
 * Supabase (Edge Function):
 * - Returns 200 OK immediately
 * - Processes webhook in background via ctx.waitUntil()
 * - Uses console.log (captured by Supabase)
 * - Calls separate sync-transactions function
 * - No user authentication (webhooks use service role)
 */
