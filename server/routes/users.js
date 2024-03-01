const express = require('express');
const { retrieveAccountsByUserId } = require('../db/queries/accounts');
const { retrieveItemsByUser } = require('../db/queries/items');
const { retrieveTransactionsByUserId } = require('../db/queries/transactions');
const { sanitizeItems, sanitizeAccounts } = require('../utils/sanitize');
const { asyncWrapper } = require('../middleware');

const router = express.Router();

/**
 * Retrieves all items associated with a single user.
 *
 * @param {string} userId the ID of the user.
 * @returns {Object[]} an array of items.
 */
router.get(
  '/:userId/items',
  asyncWrapper(async (req, res) => {
    const userId = req.userId;
    console.log(`Retrieving user items for user ${userId}`);
    const items = await retrieveItemsByUser(userId);
    res.json(sanitizeItems(items));
  })
);

/**
 * Retrieves all accounts associated with a single user.
 *
 * @param {string} userId the ID of the user.
 * @returns {Object[]} an array of accounts.
 */
router.get(
  '/accounts',
  asyncWrapper(async (req, res) => {
    const userId = req.userId;
    console.log(`Retrieving user accounts for user ${userId}`);
    const accounts = await retrieveAccountsByUserId(userId);
    console.log('Retrieved ' + accounts.length + ' accounts');
    res.json(sanitizeAccounts(accounts));
  })
);

/**
 * Retrieves all transactions associated with a single user.
 *
 * @param {string} userId the ID of the user.
 * @returns {Object[]} an array of transactions
 */
router.get(
  '/transactions',
  asyncWrapper(async (req, res) => {
    const userId = req.userId;
    console.log(`Retrieving user transactions for user ${userId}`);
    const transactions = await retrieveTransactionsByUserId(userId);
    res.json(sanitizeTransactions(transactions));
  })
);

module.exports = router;
