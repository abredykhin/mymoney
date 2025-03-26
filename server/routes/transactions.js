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
 * Utility function to sanitize transaction objects
 * @param {Array} transactions Array of transaction objects
 * @returns {Array} Sanitized transaction objects with consistent fields
 */
const sanitizeTransactions = transactions => {
  return transactions.map(transaction =>
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
};

/**
 * Retrieves transactions for a user with cursor-based pagination and filtering.
 *
 * @param {Object} req.query.limit Number of transactions to return (default: 50)
 * @param {Object} req.query.cursor Pagination cursor (optional)
 * @param {Object} req.query.category Filter by category (optional)
 * @param {Object} req.query.startDate Filter by start date (optional)
 * @param {Object} req.query.endDate Filter by end date (optional)
 * @param {Object} req.query.search Search in name or merchant name (optional)
 * @returns {Object} Response containing transactions array and pagination metadata
 */
router.get(
  '/all',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const userId = req.userId;
    const limit = parseInt(req.query.limit ?? 50, 10);
    const cursor = req.query.cursor || null;

    // Extract filter params
    const filters = {};
    if (req.query.category) filters.category = req.query.category;
    if (req.query.startDate) filters.startDate = req.query.startDate;
    if (req.query.endDate) filters.endDate = req.query.endDate;
    if (req.query.search) filters.search = req.query.search;

    debug(
      `Retrieving user transactions for user ${userId} with pagination and filters`
    );
    logger.info(
      `Retrieving user transactions for user ${userId} with pagination and filters`
    );

    const options = {
      limit,
      cursor,
      filters: Object.keys(filters).length > 0 ? filters : undefined,
    };

    const result = await retrieveTransactionsByUserId(userId, options);

    // Handle both new and legacy response formats
    const transactions = Array.isArray(result) ? result : result.transactions;

    debug(`Got ${transactions.length} transactions. Processing`);
    const sanitizedTransactions = sanitizeTransactions(transactions);

    // Construct response with pagination info if available
    const response = { transactions: sanitizedTransactions };

    if (!Array.isArray(result) && result.pagination) {
      response.pagination = result.pagination;
    }

    if (response.pagination) {
      logger.info(`Pagination available: ${response.pagination}`);
    } else {
      logger.info('No pagination available');
    }

    debug('Sending the result back to client');
    logger.info('Sending the result back to client');
    res.json(response);
  })
);

/**
 * Retrieves transactions for an item with cursor-based pagination and filtering.
 *
 * @param {string} req.itemId The ID of the item
 * @param {Object} req.query.limit Number of transactions to return (default: 50)
 * @param {Object} req.query.cursor Pagination cursor (optional)
 * @param {Object} req.query.category Filter by category (optional)
 * @param {Object} req.query.startDate Filter by start date (optional)
 * @param {Object} req.query.endDate Filter by end date (optional)
 * @param {Object} req.query.search Search in name or merchant name (optional)
 * @returns {Object} Response containing transactions array and pagination metadata
 */
router.get(
  '/item',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const itemId = req.itemId;
    const limit = parseInt(req.query.limit ?? 50, 10);
    const cursor = req.query.cursor || null;

    // Extract filter params
    const filters = {};
    if (req.query.category) filters.category = req.query.category;
    if (req.query.startDate) filters.startDate = req.query.startDate;
    if (req.query.endDate) filters.endDate = req.query.endDate;
    if (req.query.search) filters.search = req.query.search;

    debug(
      `Retrieving user transactions for item ${itemId} with pagination and filters`
    );
    logger.info(
      `Retrieving user transactions for item ${itemId} with pagination and filters`
    );

    const options = {
      limit,
      cursor,
      filters: Object.keys(filters).length > 0 ? filters : undefined,
    };

    const result = await retrieveTransactionsByItemId(itemId, options);

    // Handle both new and legacy response formats
    const transactions = Array.isArray(result) ? result : result.transactions;

    debug(`Got ${transactions.length} transactions. Processing`);
    const sanitizedTransactions = sanitizeTransactions(transactions);

    // Construct response with pagination info if available
    const response = { transactions: sanitizedTransactions };

    if (!Array.isArray(result) && result.pagination) {
      response.pagination = result.pagination;
    }

    debug('Sending the result back to client');
    logger.info('Sending the result back to client');
    res.json(response);
  })
);

/**
 * Retrieves transactions for an account with cursor-based pagination and filtering.
 *
 * @param {string} req.query.accountId The ID of the account
 * @param {Object} req.query.limit Number of transactions to return (default: 50)
 * @param {Object} req.query.cursor Pagination cursor (optional)
 * @param {Object} req.query.category Filter by category (optional)
 * @param {Object} req.query.startDate Filter by start date (optional)
 * @param {Object} req.query.endDate Filter by end date (optional)
 * @param {Object} req.query.search Search in name or merchant name (optional)
 * @returns {Object} Response containing transactions array and pagination metadata
 */
router.get(
  '/account',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const accountId = req.query.accountId;
    const limit = parseInt(req.query.limit ?? 50, 10);
    const cursor = req.query.cursor || null;

    // Extract filter params
    const filters = {};
    if (req.query.category) filters.category = req.query.category;
    if (req.query.startDate) filters.startDate = req.query.startDate;
    if (req.query.endDate) filters.endDate = req.query.endDate;
    if (req.query.search) filters.search = req.query.search;

    debug(
      `Looking up user transactions for account ${accountId} with limit ${limit}, cursor: ${cursor || 'none'}, filters: ${JSON.stringify(filters)}`
    );
    logger.info(
      `Looking up user transactions for account ${accountId} with limit ${limit}, cursor: ${cursor || 'none'}`
    );

    const options = {
      limit,
      cursor,
      filters: Object.keys(filters).length > 0 ? filters : undefined,
    };

    const result = await retrieveTransactionsByAccountId(accountId, options);

    // Handle both new and legacy response formats
    const transactions = Array.isArray(result) ? result : result.transactions;

    debug(`Got ${transactions.length} transactions. Processing...`);
    const sanitizedTransactions = sanitizeTransactions(transactions);

    // Construct response with pagination info if available
    const response = { transactions: sanitizedTransactions };

    if (!Array.isArray(result) && result.pagination) {
      response.pagination = result.pagination;
    }

    debug('Sending the result back to client');
    logger.info('Sending the result back to client');
    res.json(response);
  })
);

/**
 * Retrieves recent transactions with cursor-based pagination and filtering.
 *
 * @param {Object} req.query.limit Number of transactions to return (default: 10)
 * @param {Object} req.query.cursor Pagination cursor (optional)
 * @param {Object} req.query.category Filter by category (optional)
 * @param {Object} req.query.startDate Filter by start date (optional)
 * @param {Object} req.query.endDate Filter by end date (optional)
 * @param {Object} req.query.search Search in name or merchant name (optional)
 * @returns {Object} Response containing transactions array and pagination metadata
 */
router.get(
  '/recent',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const { userId } = req;
    const limit = parseInt(req.query.limit ?? 10, 10);
    const cursor = req.query.cursor || null;

    // Extract filter params
    const filters = {};
    if (req.query.category) filters.category = req.query.category;
    if (req.query.startDate) filters.startDate = req.query.startDate;
    if (req.query.endDate) filters.endDate = req.query.endDate;
    if (req.query.search) filters.search = req.query.search;

    debug(
      `Looking up recent transactions for all accounts with limit ${limit}, cursor: ${cursor || 'none'}, filters: ${JSON.stringify(filters)}`
    );
    logger.info(
      `Looking up recent transactions for all accounts with limit ${limit}, cursor: ${cursor || 'none'}`
    );

    const options = {
      limit,
      cursor,
      filters: Object.keys(filters).length > 0 ? filters : undefined,
    };

    const result = await retrieveTransactionsByUserId(userId, options);

    // Handle both new and legacy response formats
    const transactions = Array.isArray(result) ? result : result.transactions;

    debug(`Got ${transactions.length} transactions. Processing`);
    const sanitizedTransactions = sanitizeTransactions(transactions);

    // Construct response with pagination info if available
    const response = { transactions: sanitizedTransactions };

    if (!Array.isArray(result) && result.pagination) {
      response.pagination = result.pagination;
    }

    debug('Sending the result back to client');
    logger.info('Sending the result back to client');
    res.json(response);
  })
);

module.exports = router;
