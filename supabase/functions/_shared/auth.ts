/**
 * Authentication utilities for Supabase Edge Functions
 *
 * Phase 2: Authentication Replacement
 * These utilities replace the legacy session token system with Supabase Auth (JWT-based).
 */

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

/**
 * Result type for authentication operations
 */
export interface AuthResult {
  user: {
    id: string;
    email?: string;
  } | null;
  error: Error | null;
}

/**
 * Creates a Supabase client configured for user authentication.
 * This client will use the JWT token from the Authorization header.
 *
 * @param req - The incoming HTTP request
 * @returns Configured Supabase client with user context
 *
 * @example
 * ```typescript
 * const supabase = createAuthenticatedClient(req);
 * // All queries will automatically filter by user.id via RLS
 * const { data } = await supabase.from('items').select('*');
 * ```
 */
export function createAuthenticatedClient(req: Request): SupabaseClient {
  const authHeader = req.headers.get('Authorization');

  if (!authHeader) {
    throw new Error('Missing Authorization header');
  }

  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    {
      global: {
        headers: { Authorization: authHeader }
      }
    }
  );
}

/**
 * Creates a Supabase client with service role privileges.
 * Use this ONLY for webhooks or cron jobs where there is no user context.
 *
 * WARNING: This client bypasses Row Level Security (RLS)!
 *
 * @returns Supabase client with service role access
 *
 * @example
 * ```typescript
 * // For webhook functions that process data for any user
 * const supabase = createServiceRoleClient();
 * const { data } = await supabase
 *   .from('items')
 *   .select('*')
 *   .eq('plaid_item_id', itemId);
 * ```
 */
export function createServiceRoleClient(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );
}

/**
 * Retrieves the authenticated user from the request.
 * Returns the user object or null if authentication fails.
 *
 * @param req - The incoming HTTP request
 * @returns AuthResult containing user or error
 *
 * @example
 * ```typescript
 * const { user, error } = await getAuthenticatedUser(req);
 * if (error || !user) {
 *   return new Response('Unauthorized', { status: 401 });
 * }
 * // Use user.id for queries
 * ```
 */
export async function getAuthenticatedUser(req: Request): Promise<AuthResult> {
  try {
    const supabase = createAuthenticatedClient(req);
    const { data: { user }, error } = await supabase.auth.getUser();

    if (error) {
      return { user: null, error };
    }

    if (!user) {
      return { user: null, error: new Error('No user found') };
    }

    return { user, error: null };
  } catch (error) {
    return { user: null, error: error as Error };
  }
}

/**
 * Middleware-style function that verifies authentication and returns a 401 if invalid.
 * Use this for endpoints that require authentication.
 *
 * @param req - The incoming HTTP request
 * @returns The authenticated user or a 401 Response
 *
 * @example
 * ```typescript
 * Deno.serve(async (req) => {
 *   const authResult = await requireAuth(req);
 *
 *   // If authentication failed, return the error response
 *   if (authResult instanceof Response) {
 *     return authResult;
 *   }
 *
 *   // Otherwise, use the authenticated user
 *   const user = authResult;
 *   // ... your function logic
 * });
 * ```
 */
export async function requireAuth(req: Request): Promise<AuthResult['user'] | Response> {
  const { user, error } = await getAuthenticatedUser(req);

  if (error || !user) {
    return new Response(
      JSON.stringify({
        error: 'Unauthorized',
        message: error?.message || 'Authentication required'
      }),
      {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }

  return user;
}

/**
 * Standard CORS headers for Edge Functions
 */
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info, apikey',
};

/**
 * Handles CORS preflight requests
 *
 * @param req - The incoming HTTP request
 * @returns Response with CORS headers or null if not an OPTIONS request
 *
 * @example
 * ```typescript
 * Deno.serve(async (req) => {
 *   const corsResponse = handleCors(req);
 *   if (corsResponse) return corsResponse;
 *
 *   // ... rest of your function
 * });
 * ```
 */
export function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  return null;
}

/**
 * Creates a JSON response with proper headers
 *
 * @param data - The data to serialize as JSON
 * @param status - HTTP status code (default: 200)
 * @param additionalHeaders - Additional headers to include
 * @returns Response with JSON body and headers
 *
 * @example
 * ```typescript
 * return jsonResponse({ message: 'Success', data: items }, 200);
 * ```
 */
export function jsonResponse(
  data: unknown,
  status = 200,
  additionalHeaders: Record<string, string> = {}
): Response {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders,
        ...additionalHeaders,
      },
    }
  );
}
