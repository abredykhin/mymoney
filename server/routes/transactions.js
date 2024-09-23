const express = require('express');
const {
  retrieveTransactionsByUserId,
  retrieveTransactionsByItemId,
  retrieveTransactionsByAccountId,
} = require('../db/queries/transactions');
const { asyncWrapper, verifyToken } = require('../middleware');

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
    console.log(`Retrieving user transactions for user ${userId}`);
    const transactions = await retrieveTransactionsByUserId(userId, limit);
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
    const accountId = req.accountId;
    const limit = req.maxCount ?? 50;
    console.log(`Retrieving user transactions for account ${accountId}`);
    const transactions = await retrieveTransactionsByAccountId(
      accountId,
      limit
    );
    res.json(sanitizeTransactions(transactions));
  })
);

module.exports = router;
