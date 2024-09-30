/**
 * @file Defines helpers for updating transactions on an item
 */

const plaid = require('./loggingPlaidClient');
const {
  retrieveItemByPlaidItemId,
  createAccounts,
  createOrUpdateTransactions,
  deleteTransactions,
  updateItemTransactionsCursor,
} = require('../db/queries');
const debug = require('debug')('plaid:syncTransactions');
const Boom = require('@hapi/boom');

/**
 * Handles the fetching and storing of new, modified, or removed transactions
 *
 * @param {string} plaidItemId the Plaid ID for the item.
 */
const syncTransactions = async plaidItemId => {
  debug(`Starting transaction sync for plaid item: ${plaidItemId}`);
  // Fetch new transactions from plaid api.
  const { added, modified, removed, cursor, accessToken } =
    await fetchNewSyncData(plaidItemId);

  const request = {
    access_token: accessToken,
  };

  debug('Got transactions data. Now refresing accounts info from Plaid.');
  const {
    data: { accounts },
  } = await plaid.accountsGet(request);

  debug(
    `Ready to update data in db. Transactions added: ${added.length}, modified: ${modified.length}, removed: ${removed.length}`
  );

  debug('Updating accounts data...');
  await createAccounts(plaidItemId, accounts);
  debug('Updating transactions data...');
  await createOrUpdateTransactions(added.concat(modified));
  debug('Deleting obsolete transactions...');
  await deleteTransactions(removed);
  debug('Updating item transactions cursor');
  await updateItemTransactionsCursor(plaidItemId, cursor);
  debug('Transaction sync is complete.');
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
  const fetchNewSyncDataDebug = debug.extend('fetchSyncData');

  fetchNewSyncDataDebug('Looking up item in db');
  const item = await retrieveItemByPlaidItemId(plaidItemId);
  if (!item) {
    fetchNewSyncDataDebug('Item not found in db. Aborting sync operation');
    throw Boom.badRequest('Item not found.');
  }

  const {
    plaid_access_token: accessToken,
    last_transactions_update_cursor: lastCursor,
  } = item;

  let cursor = lastCursor;

  // New transaction updates since "cursor"
  let added = [];
  let modified = [];
  // Removed transaction ids
  let removed = [];
  let hasMore = true;

  const batchSize = 100;
  fetchNewSyncDataDebug('Item found. Beginning comms with Plaid');
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
      fetchNewSyncDataDebug('Asking Plaid for new sync data');
      const response = await plaid.transactionsSync(request);
      const data = response.data;
      // Add this page of results
      added = added.concat(data.added);
      modified = modified.concat(data.modified);
      removed = removed.concat(data.removed);
      hasMore = data.has_more;
      fetchNewSyncDataDebug(
        `Processed the response. More data available?: ${hasMore}`
      );
      // Update cursor to the next cursor
      cursor = data.next_cursor;
    }
  } catch (err) {
    fetchNewSyncDataDebug(`Error fetching transactions: ${err.message}`);
    cursor = lastCursor;
  }
  return { added, modified, removed, cursor, accessToken };
};

module.exports = syncTransactions;
