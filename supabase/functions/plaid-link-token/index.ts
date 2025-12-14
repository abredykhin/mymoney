/**
 * Supabase Edge Function: plaid-link-token
 *
 * Generates a Plaid Link token for connecting bank accounts.
 *
 * Phase 3.1 - Migrated from server/routes/linkTokens.js
 */

import { Products, CountryCode } from 'npm:plaid@31.1.0';
import {
  requireAuth,
  handleCors,
  jsonResponse,
  createAuthenticatedClient,
} from '../_shared/auth.ts';
import {
  createPlaidClient,
  handlePlaidError,
  PLAID_WEBHOOK_URL,
  PLAID_REDIRECT_URI,
} from '../_shared/plaid.ts';

// Initialize Plaid client
const plaidClient = createPlaidClient();

interface LinkTokenRequest {
  itemId?: number;
}

/**
 * Retrieve item by ID from database
 */
async function retrieveItemById(supabase: any, itemId: number) {
  const { data, error } = await supabase
    .from('items')
    .select('plaid_access_token')
    .eq('id', itemId)
    .single();

  if (error) {
    throw new Error(`Failed to retrieve item: ${error.message}`);
  }

  return data;
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // Only allow POST requests
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    // Check if running in local development mode
    // Set IS_LOCAL_DEV="true" in config.toml [edge_runtime.secrets] for local dev
    const isLocal = Deno.env.get('IS_LOCAL_DEV') === 'true';
    console.log('🔍 Environment: isLocal =', isLocal);

    let user;
    let supabase;

    if (isLocal) {
      // Local development: Skip auth for easier testing
      console.log('⚠️  Running locally - Auth bypassed for testing');
      user = { id: 'local-test-user-123' };
      // supabase client not needed for new link mode (no itemId)
    } else {
      // Production: Require authentication
      const authResult = await requireAuth(req);
      if (authResult instanceof Response) {
        return authResult; // Return 401 if not authenticated
      }
      user = authResult;
      supabase = createAuthenticatedClient(req);
    }

    // Parse request body
    let body: LinkTokenRequest = {};
    try {
      body = await req.json();
    } catch {
      // Empty body is ok - we'll just create a new link token
    }

    const { itemId } = body;

    console.log('Creating Plaid Link token for user:', user.id);

    // Determine if this is update mode or new link mode
    let accessToken: string | null = null;
    let products: Products[] = [Products.Transactions]; // Must include transactions for webhooks

    if (itemId != null) {
      // Update mode - include access token and empty products array
      console.log('Update mode - retrieving existing item:', itemId);

      if (isLocal) {
        console.log('⚠️  Local mode: Cannot retrieve items without auth. Skipping update mode.');
        // Fall through to new link mode
      } else {
        const item = await retrieveItemById(supabase, itemId);
        accessToken = item.plaid_access_token;
        products = [];
      }
    } else {
      console.log('New link mode - creating fresh link token');
    }

    // Create link token parameters
    const linkTokenParams = {
      user: {
        // This should correspond to a unique id for the current user
        // Using Supabase user ID (UUID)
        client_user_id: user.id,
      },
      client_name: 'BabloApp',
      products: products,
      country_codes: [CountryCode.Us],
      language: 'en',
      webhook: PLAID_WEBHOOK_URL,
      access_token: accessToken,
      redirect_uri: PLAID_REDIRECT_URI,
    };

    console.log('Requesting link token from Plaid...');
    const createResponse = await plaidClient.linkTokenCreate(linkTokenParams as any);

    console.log('Successfully created link token');
    return jsonResponse(createResponse.data);

  } catch (error) {
    console.error('Error creating link token:', error);

    const errorResponse = handlePlaidError(error);
    return jsonResponse(errorResponse, 500);
  }
});

/**
 * USAGE:
 *
 * Deploy:
 *   $ cd supabase
 *   $ supabase functions deploy plaid-link-token
 *
 * Set secrets:
 *   $ supabase secrets set PLAID_CLIENT_ID=your_client_id
 *   $ supabase secrets set PLAID_SECRET=your_secret
 *   $ supabase secrets set PLAID_ENV=sandbox  # or development, production
 *
 * Test locally:
 *   $ supabase functions serve plaid-link-token
 *
 * Call from iOS:
 *   ```swift
 *   let response = try await supabase.functions.invoke(
 *     "plaid-link-token",
 *     options: FunctionInvokeOptions(
 *       method: .post,
 *       body: ["itemId": 123]  // Optional - for update mode
 *     )
 *   )
 *   ```
 *
 * Call with curl:
 *   ```bash
 *   curl -X POST 'https://[project].supabase.co/functions/v1/plaid-link-token' \
 *     -H "Authorization: Bearer [access-token]" \
 *     -H "Content-Type: application/json" \
 *     -d '{"itemId": 123}'
 *   ```
 *
 * KEY DIFFERENCES FROM LEGACY:
 *
 * Legacy (Node.js):
 * - Uses Express middleware for auth (verifyToken)
 * - User ID from req.userId (numeric ID)
 * - Plaid client initialized once at startup
 * - Uses Winston logger
 *
 * Supabase (Edge Function):
 * - Uses requireAuth() for authentication
 * - User ID from Supabase session (UUID)
 * - Plaid client initialized per request (cold starts)
 * - Uses console.log (Supabase captures these)
 * - RLS automatically filters items by user
 */
