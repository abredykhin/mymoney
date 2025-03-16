/**
 * @file Defines helpers for updating transactions on an item
 */

const plaid = require('../plaid/loggingPlaidClient');
const {
  retrieveItemByPlaidItemId,
  createAccounts,
  createOrUpdateTransactions,
  deleteTransactions,
  updateItemTransactionsCursor,
} = require('../db/queries');

const log = require('../utils/logger')('plaid:syncTransactions');

/**
 * Handles the fetching and storing of new, modified, or removed transactions
 *
 * @param {string} plaidItemId the Plaid ID for the item.
 */
const syncTransactions = async plaidItemId => {
  log.info(`Starting transaction sync for plaid item: ${plaidItemId}`);

  // Fetch new transactions from plaid api.
  const { added, modified, removed, cursor, accessToken } =
    await fetchNewSyncData(plaidItemId);

  if (!accessToken) {
    log.error('Failed to sync item. Cutting it short');
    return;
  }

  const request = {
    access_token: accessToken,
  };

  log.info('Got transactions data. Now refresing accounts info from Plaid.');
  const {
    data: { accounts },
  } = await plaid.accountsGet(request);

  log.info(
    `Ready to update data in db. Transactions added: ${added.length}, modified: ${modified.length}, removed: ${removed.length}`
  );

  log.info('Updating accounts data...');
  await createAccounts(plaidItemId, accounts);
  log.info('Updating transactions data...');
  await createOrUpdateTransactions(added.concat(modified));
  log.info('Deleting obsolete transactions...');
  await deleteTransactions(removed);
  log.info('Updating item transactions cursor');
  await updateItemTransactionsCursor(plaidItemId, cursor);
  log.info('Transaction sync is complete.');
  return {
    addedCount: added.length,
    modifiedCount: modified.length,
    removedCount: removed.length,
  };
};

/**
 * Fetches transactions from the Plaid API for a given item.
 *
 * @param {string} plaidItemId the Plaid ID for the item.
 * @returns {Object{}} an object containing transactions and a cursor.
 */
const fetchNewSyncData = async plaidItemId => {
  // New transaction updates since "cursor"
  let added = [];
  let modified = [];
  // Removed transaction ids
  let removed = [];
  let hasMore = true;

  const item = await retrieveItemByPlaidItemId(plaidItemId);
  if (!item) {
    log.error(`Item ${plaidItemId} not found in db. Aborting sync operation`);

    return {};
  }

  const { plaid_access_token: accessToken, transactions_cursor: lastCursor } =
    item;

  let cursor = lastCursor;
  log.info(`Cursor at start of sync: ${cursor}`);

  const batchSize = 100;
  log.info(`Item ${plaidItemId} found. Beginning comms with Plaid`);
  try {
    // Iterate through each page of new transaction updates for item
    while (hasMore) {
      const request = {
        access_token: accessToken,
        cursor: cursor,
        count: batchSize,
        options: {
          include_personal_finance_category: true,
        },
      };
      log.info('Asking Plaid for new sync data');
      const response = await plaid.transactionsSync(request);
      const data = response.data;
      // Add this page of results
      added = added.concat(data.added);
      modified = modified.concat(data.modified);
      removed = removed.concat(data.removed);
      hasMore = data.has_more;
      log.info(`Processed the response. More data available?: ${hasMore}`);
      // Update cursor to the next cursor
      cursor = data.next_cursor;
      log.info(`Updated cursor to ${cursor}`);
    }
  } catch (err) {
    log.error(
      `Error fetching transactions for plaidItemId: ${plaidItemId}: ${err.message}`
    );

    cursor = lastCursor;
  }
  log.info(`Finished sync. Returning cursor: ${cursor}`);
  return { added, modified, removed, cursor, accessToken };
};

module.exports = syncTransactions;
