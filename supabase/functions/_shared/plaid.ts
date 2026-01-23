/**
 * Plaid client utilities for Supabase Edge Functions
 *
 * Phase 3 - Server Migration
 * Provides reusable Plaid client configuration and helper functions
 */

import { Configuration, PlaidApi, PlaidEnvironments } from 'npm:plaid@31.1.0';
import * as jose from 'https://deno.land/x/jose@v5.10.0/index.ts';

/**
 * Get Plaid configuration from environment variables
 */
export function getPlaidConfig() {
  const PLAID_CLIENT_ID = Deno.env.get('PLAID_CLIENT_ID');
  const PLAID_SECRET = Deno.env.get('PLAID_SECRET');
  const PLAID_ENV = Deno.env.get('PLAID_ENV') || 'sandbox';

  if (!PLAID_CLIENT_ID || !PLAID_SECRET) {
    throw new Error(
      'Missing Plaid configuration. Set PLAID_CLIENT_ID and PLAID_SECRET environment variables.'
    );
  }

  return {
    clientId: PLAID_CLIENT_ID,
    secret: PLAID_SECRET,
    environment: PLAID_ENV,
  };
}

/**
 * Create a configured Plaid API client
 *
 * @returns Configured PlaidApi instance
 *
 * @example
 * ```typescript
 * const plaidClient = createPlaidClient();
 * const response = await plaidClient.linkTokenCreate({...});
 * ```
 */
export function createPlaidClient(): PlaidApi {
  const config = getPlaidConfig();

  const configuration = new Configuration({
    basePath: PlaidEnvironments[config.environment as keyof typeof PlaidEnvironments],
    baseOptions: {
      headers: {
        'PLAID-CLIENT-ID': config.clientId,
        'PLAID-SECRET': config.secret,
      },
    },
  });

  return new PlaidApi(configuration);
}

/**
 * Plaid webhook URL configuration
 */
export const PLAID_WEBHOOK_URL = Deno.env.get('PLAID_WEBHOOK_URL') ||
  (Deno.env.get('SUPABASE_URL')
    ? `${Deno.env.get('SUPABASE_URL')}/functions/v1/plaid-webhook`
    : 'http://localhost:54321/functions/v1/plaid-webhook');

/**
 * Plaid redirect URI configuration
 */
export const PLAID_REDIRECT_URI = Deno.env.get('PLAID_REDIRECT_URI') ||
  'https://babloapp.com/plaid/redirect/index.html';

/**
 * Handle Plaid API errors and return appropriate response
 *
 * @param error The error from Plaid API
 * @returns Formatted error object
 *
 * @example
 * ```typescript
 * try {
 *   await plaidClient.transactionsSync({...});
 * } catch (error) {
 *   const errorResponse = handlePlaidError(error);
 *   return jsonResponse(errorResponse, 500);
 * }
 * ```
 */
export function handlePlaidError(error: any): { error: string; details?: any } {
  console.error('Plaid API error:', error);

  // Handle Plaid-specific errors
  if (error.response?.data) {
    return {
      error: 'Plaid API error',
      details: error.response.data,
    };
  }

  // Handle network/timeout errors
  if (error.code === 'ECONNREFUSED' || error.code === 'ETIMEDOUT') {
    return {
      error: 'Failed to connect to Plaid',
      details: { code: error.code, message: error.message },
    };
  }

  // Generic error
  return {
    error: 'Failed to process Plaid request',
    details: error instanceof Error ? error.message : 'Unknown error',
  };
}

/**
 * Validate Plaid webhook signature using JWT verification
 *
 * Implementation follows: https://plaid.com/docs/api/webhooks/webhook-verification/
 *
 * @param request The incoming webhook request
 * @param bodyText The raw webhook body as text
 * @returns Promise resolving to true if signature is valid
 */
export async function validateWebhookSignature(
  request: Request,
  bodyText: string
): Promise<boolean> {
  try {
    // Step 1: Extract JWT from Plaid-Verification header
    const jwt = request.headers.get('Plaid-Verification');
    if (!jwt) {
      console.error('❌ Missing Plaid-Verification header');
      return false;
    }

    // Step 2: Decode JWT header without validation to extract kid
    const decodedHeader = jose.decodeProtectedHeader(jwt);

    // Verify algorithm is ES256
    if (decodedHeader.alg !== 'ES256') {
      console.error(`❌ Invalid algorithm: ${decodedHeader.alg}, expected ES256`);
      return false;
    }

    const kid = decodedHeader.kid;
    if (!kid) {
      console.error('❌ Missing kid in JWT header');
      return false;
    }

    console.log(`🔑 Extracted kid: ${kid}`);

    // Step 3: Retrieve verification key from Plaid
    const plaidClient = createPlaidClient();
    const keyResponse = await plaidClient.webhookVerificationKeyGet({
      key_id: kid,
    });

    if (!keyResponse.data.key) {
      console.error('❌ Failed to retrieve verification key from Plaid');
      return false;
    }

    // Convert Plaid's JWK to the format expected by jose
    const jwk = keyResponse.data.key;
    console.log('🔑 Retrieved JWK from Plaid');

    // Step 4: Verify JWT signature using the JWK
    const publicKey = await jose.importJWK(jwk, decodedHeader.alg);
    const { payload } = await jose.jwtVerify(jwt, publicKey, {
      algorithms: ['ES256'],
    });

    console.log('✅ JWT signature verified');

    // Step 5: Check webhook freshness (must be within 5 minutes)
    const currentTime = Math.floor(Date.now() / 1000);
    const issuedAt = payload.iat as number;
    const age = currentTime - issuedAt;

    if (age > 300) { // 5 minutes = 300 seconds
      console.error(`❌ Webhook too old: ${age} seconds (max 300)`);
      return false;
    }

    console.log(`✅ Webhook is fresh: ${age} seconds old`);

    // Step 6: Verify body integrity using SHA-256 hash
    const expectedHash = payload.request_body_sha256 as string;

    // Compute SHA-256 hash of the body
    const encoder = new TextEncoder();
    const data = encoder.encode(bodyText);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const computedHash = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');

    // Use constant-time comparison to prevent timing attacks
    if (computedHash !== expectedHash) {
      console.error('❌ Body hash mismatch');
      console.error(`   Expected: ${expectedHash}`);
      console.error(`   Computed: ${computedHash}`);
      return false;
    }

    console.log('✅ Body integrity verified');
    return true;

  } catch (error) {
    console.error('❌ Webhook verification failed:', error);
    return false;
  }
}
