const express = require('express');
const Boom = require('@hapi/boom');

const noAuthRouter = express.Router();
const authRouter = express.Router();

/**
 * Legacy auth routes removed - now using Supabase Auth (Sign in with Apple)
 * See: /server/archived/phase2-auth-migration/
 *
 * Authentication is now handled by:
 * - iOS: Sign in with Apple → Supabase Auth
 * - Backend: Supabase Edge Functions (plaid-link-token, plaid-webhook, etc.)
 */

/**
 * Throws a 404 not found error for all requests.
 */
noAuthRouter.get('*', (req, res) => {
  throw Boom('not found', { statusCode: 404 });
});

module.exports = { noAuthRouter, authRouter };
