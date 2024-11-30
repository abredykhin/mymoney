const express = require('express');
const {
  retrieveTransactionsByUserId,
  retrieveTransactionsByItemId,
  retrieveTransactionsByAccountId,
} = require('../db/queries/transactions');
const { asyncWrapper, verifyToken } = require('../middleware');
const _ = require('lodash');
const debug = require('debug')('routes:transactions');
const logger = require('../utils/logger');

const router = express.Router();

/**
 * Retrieves all transactions associated with a single user.
 *
 * @returns {Object[]} an array of transactions
 */
router.get(
  '/all',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const userId = req.userId;
    const limit = req.maxCount ?? 50;
    debug(`Retrieving user transactions for user ${userId}`);
    logger.info('Retrieving user transactions for user %s', userId);
    const transactions = await retrieveTransactionsByUserId(userId, limit);
    debug('Got all the transactions. Sending them back');
    logger.info('Got all the transactions. Sending them back');
    res.json(sanitizeTransactions(transactions));
  })
);

/**
 * Retrieves all transactions associated with an item.
 *
 * @param {string} itemId the ID of the item
 * @param {integer} maxCount query limit
 * @returns {Object[]} an array of transactions
 */
router.get(
  '/item',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const itemId = req.itemId;
    const limit = req.maxCount ?? 50;
    console.log(`Retrieving user transactions for item ${itemId}`);
    logger.info('Retrieving user transactions for item %s', itemId);
    const transactions = await retrieveTransactionsByItemId(itemId, limit);
    res.json(sanitizeTransactions(transactions));
  })
);

/**
 * Retrieves all transactions associated with an item.
 *
 * @param {string} accountId the ID of the account
 * @param {integer} maxCount query limit
 * @returns {Object[]} an array of transactions
 */
router.get(
  '/account',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const accountId = req.query.accountId;
    const limit = req.query.maxCount ?? 50;
    debug(
      `Looking up user transactions for account ${accountId} and maxCount ${limit}`
    );
    logger.info(
      `Looking up user transactions for account ${accountId} and maxCount ${limit}`
    );
    const transactions = await retrieveTransactionsByAccountId(
      accountId,
      limit
    );

    debug('Got the transactions. Processing...');
    const sanitizedTransactions = transactions.map(transaction =>
      _.pick(transaction, [
        'id',
        'account_id',
        'amount',
        'iso_currency_code',
        'date',
        'authorized_date',
        'transaction_id',
        'subcategory',
        'personal_finance_category',
        'personal_finance_subcategory',
        'type',
        'name',
        'pending',
        'merchant_name',
        'logo_url',
        'website',
        'payment_channel',
      ])
    );

    const response = { transactions: sanitizedTransactions };
    debug('Sending the result back to client');
    logger.info('Sending the result back to client');
    res.json(response);
  })
);

/**
 * Retrieves all transactions associated with an item.
 *
 * @param {string} accountId the ID of the account
 * @param {integer} maxCount query limit
 * @returns {Object[]} an array of transactions
 */
router.get(
  '/recent',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const { userId } = req;
    const limit = req.query.maxCount ?? 10;
    debug(
      `Looking up recent transactions for all accounts with maxCount ${limit}`
    );
    logger.info(
      `Looking up recent transactions for all accounts with maxCount ${limit}`
    );
    const transactions = await retrieveTransactionsByUserId(userId, limit);

    debug('Got the transactions. Processing...');
    const sanitizedTransactions = transactions.map(transaction =>
      _.pick(transaction, [
        'id',
        'account_id',
        'amount',
        'iso_currency_code',
        'date',
        'authorized_date',
        'transaction_id',
        'subcategory',
        'personal_finance_category',
        'personal_finance_subcategory',
        'type',
        'name',
        'pending',
        'merchant_name',
        'logo_url',
        'website',
        'payment_channel',
      ])
    );

    const response = { transactions: sanitizedTransactions };
    debug('Sending the result back to client');
    logger.info('Sending the result back to client');
    res.json(response);
  })
);

module.exports = router;
