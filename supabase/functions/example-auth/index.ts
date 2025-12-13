/**
 * Example Edge Function demonstrating Supabase Auth integration
 *
 * Phase 2: Authentication Replacement
 * This example shows how to use the auth utilities for different scenarios.
 *
 * This is a REFERENCE IMPLEMENTATION - not meant for production use.
 * Use this as a template when creating new Edge Functions in Phase 3.
 */

import {
  requireAuth,
  handleCors,
  jsonResponse,
  createAuthenticatedClient,
} from '../_shared/auth.ts';

/**
 * Example 1: Simple authenticated endpoint
 * This is the most common pattern - verify auth and use the user context
 */
async function handleAuthenticatedRequest(req: Request) {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // Require authentication (returns 401 if not authenticated)
  const authResult = await requireAuth(req);
  if (authResult instanceof Response) {
    return authResult; // Return the 401 error response
  }

  const user = authResult; // Now we have the authenticated user

  // Create Supabase client with user context
  // All queries will automatically filter by user.id via RLS
  const supabase = createAuthenticatedClient(req);

  // Example: Get user's items
  const { data: items, error } = await supabase
    .from('items')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) {
    return jsonResponse(
      { error: 'Database error', message: error.message },
      500
    );
  }

  // Return data with user info
  return jsonResponse({
    user: {
      id: user.id,
      email: user.email,
    },
    items,
    message: 'Successfully retrieved items for authenticated user',
  });
}

/**
 * Example 2: Authenticated POST request with body parsing
 */
async function handleAuthenticatedPost(req: Request) {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  const authResult = await requireAuth(req);
  if (authResult instanceof Response) {
    return authResult;
  }

  const user = authResult;

  // Parse request body
  let body;
  try {
    body = await req.json();
  } catch (error) {
    return jsonResponse(
      { error: 'Invalid JSON', message: 'Request body must be valid JSON' },
      400
    );
  }

  // Validate input
  const { name } = body;
  if (!name) {
    return jsonResponse(
      { error: 'Validation error', message: 'Name is required' },
      400
    );
  }

  const supabase = createAuthenticatedClient(req);

  // Create a new item (user_id will be set via RLS or explicitly)
  const { data, error } = await supabase
    .from('items')
    .insert({
      user_id: user.id, // Explicitly set user_id for clarity
      plaid_item_id: `example_${Date.now()}`,
      plaid_access_token: 'encrypted_token_here',
      plaid_institution_id: 'ins_example',
    })
    .select()
    .single();

  if (error) {
    return jsonResponse(
      { error: 'Database error', message: error.message },
      500
    );
  }

  return jsonResponse({
    message: 'Item created successfully',
    item: data,
  }, 201);
}

/**
 * Main handler - routes based on HTTP method
 */
Deno.serve(async (req) => {
  try {
    const { pathname } = new URL(req.url);

    // Route based on method
    if (req.method === 'GET') {
      return await handleAuthenticatedRequest(req);
    }

    if (req.method === 'POST') {
      return await handleAuthenticatedPost(req);
    }

    // Method not allowed
    return jsonResponse(
      { error: 'Method not allowed' },
      405
    );
  } catch (error) {
    // Global error handler
    console.error('Unhandled error:', error);
    return jsonResponse(
      {
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
      },
      500
    );
  }
});

/**
 * USAGE EXAMPLES:
 *
 * 1. Deploy the function:
 *    $ cd supabase
 *    $ supabase functions deploy example-auth
 *
 * 2. Test locally:
 *    $ supabase functions serve example-auth
 *
 * 3. Call from iOS app (authenticated):
 *    ```swift
 *    let response = try await supabase.functions.invoke(
 *      "example-auth",
 *      options: FunctionInvokeOptions(
 *        method: .get
 *      )
 *    )
 *    ```
 *
 * 4. Call with curl (for testing):
 *    ```bash
 *    # First, sign in to get a JWT token
 *    curl -X POST 'https://[project].supabase.co/auth/v1/token?grant_type=password' \
 *      -H "apikey: [anon-key]" \
 *      -H "Content-Type: application/json" \
 *      -d '{"email":"user@example.com","password":"password"}'
 *
 *    # Then use the access_token from response
 *    curl 'https://[project].supabase.co/functions/v1/example-auth' \
 *      -H "Authorization: Bearer [access-token]" \
 *      -H "Content-Type: application/json"
 *    ```
 *
 * KEY DIFFERENCES FROM LEGACY AUTH:
 *
 * Legacy (Node.js):
 * - Custom session tokens stored in database
 * - verifyToken middleware attaches user to req.user
 * - Manual user_id filtering in queries
 *
 * Supabase (Edge Functions):
 * - JWT tokens (no database lookup needed)
 * - requireAuth() function for authentication
 * - RLS automatically filters by user.id
 * - Token refresh handled automatically by client SDK
 */
