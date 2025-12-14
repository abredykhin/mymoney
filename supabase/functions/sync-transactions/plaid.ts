/**
 * Plaid API integration for sync-transactions Edge Function
 *
 * Handles fetching transaction updates and account balances from Plaid.
 */

import { createPlaidClient } from '../_shared/plaid.ts';
import type { Item, TransactionUpdates, PlaidAccount, PlaidTransaction, PlaidRemovedTransaction } from './types.ts';

/**
 * Fetch transaction updates from Plaid using cursor-based pagination
 *
 * Loops through Plaid's paginated responses until has_more=false,
 * accumulating all added, modified, and removed transactions.
 *
 * @param item - Database item with access token and cursor
 * @returns Transaction updates and next cursor
 */
export async function fetchTransactionUpdates(item: Item): Promise<TransactionUpdates> {
  const plaidClient = createPlaidClient();

  let added: PlaidTransaction[] = [];
  let modified: PlaidTransaction[] = [];
  let removed: PlaidRemovedTransaction[] = [];
  let hasMore = true;
  let cursor = item.transactions_cursor;

  console.log(`🔄 Starting Plaid sync with cursor: ${cursor || 'null (initial sync)'}`);

  try {
    let pageCount = 0;

    while (hasMore) {
      pageCount++;
      console.log(`📡 Fetching page ${pageCount} from Plaid...`);

      const request = {
        access_token: item.plaid_access_token,
        cursor: cursor || undefined, // Convert null to undefined for Plaid SDK
        count: 100, // Fetch 100 transactions per request
        options: {
          include_personal_finance_category: true,
        },
      };

      const response = await plaidClient.transactionsSync(request);
      const data = response.data;

      // Accumulate results across pages (cast to our types)
      added = added.concat(data.added as any);
      modified = modified.concat(data.modified as any);
      removed = removed.concat(data.removed as any);

      hasMore = data.has_more;
      cursor = data.next_cursor;

      console.log(
        `📊 Page ${pageCount}: +${data.added.length} ~${data.modified.length} -${data.removed.length} | hasMore: ${hasMore}`
      );
    }

    console.log(
      `✅ Plaid sync complete (${pageCount} pages): +${added.length} ~${modified.length} -${removed.length}`
    );

    return {
      added,
      modified,
      removed,
      nextCursor: cursor,
    };
  } catch (error: any) {
    // Handle Plaid-specific errors
    if (error.response?.status === 429) {
      console.error('❌ Plaid rate limit exceeded');
      throw new Error('RATE_LIMIT_EXCEEDED');
    }

    if (error.response?.data?.error_code === 'ITEM_LOGIN_REQUIRED') {
      console.error('❌ Item requires user re-authentication');
      throw new Error('ITEM_LOGIN_REQUIRED');
    }

    // Generic Plaid error
    console.error('❌ Plaid API error:', error.response?.data || error.message);
    throw new Error(`Plaid sync failed: ${error.message}`);
  }
}

/**
 * Fetch updated account balances from Plaid
 *
 * @param accessToken - Plaid access token
 * @returns Array of accounts with current balances
 */
export async function fetchAccountBalances(accessToken: string): Promise<PlaidAccount[]> {
  const plaidClient = createPlaidClient();

  console.log(`💰 Fetching account balances from Plaid...`);

  try {
    const response = await plaidClient.accountsGet({
      access_token: accessToken,
    });

    const accounts = response.data.accounts as unknown as PlaidAccount[];
    console.log(`✅ Retrieved ${accounts.length} accounts`);

    return accounts;
  } catch (error: any) {
    console.error('❌ Failed to fetch account balances:', error.response?.data || error.message);
    throw new Error(`Failed to fetch account balances: ${error.message}`);
  }
}
