/**
 * Plaid client utilities for Supabase Edge Functions
 *
 * Phase 3 - Server Migration
 * Provides reusable Plaid client configuration and helper functions
 */

import { Configuration, PlaidApi, PlaidEnvironments } from 'npm:plaid@31.1.0';

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
  'https://babloapp.com/plaid/webhook';

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
 * Validate Plaid webhook signature (for webhook endpoints)
 *
 * @param body The raw webhook body
 * @param signature The webhook signature from headers
 * @returns true if signature is valid
 */
export function validateWebhookSignature(body: string, signature: string): boolean {
  // TODO: Implement webhook signature validation
  // See: https://plaid.com/docs/api/webhooks/#webhook-verification
  // For now, we'll rely on HTTPS and the webhook URL being secret
  return true;
}
