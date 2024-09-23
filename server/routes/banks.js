const express = require('express');
const { retrieveAccountsByItemId } = require('../db/queries/accounts');
const { retrieveItemsByUser } = require('../db/queries/items');
const { asyncWrapper, verifyToken } = require('../middleware');
const _ = require('lodash');

const router = express.Router();

/**
 * Retrieves all banks and accounts associated with a single user.
 */
router.get(
  '/banksWithAccounts',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const userId = req.userId;
    console.log(`Retrieving user items for user ${userId}`);
    const items = await retrieveItemsByUser(userId);

    const banksWithAccounts = await Promise.all(
      items.map(async item => {
        const bank = {
          id: item.id,
          bank_name: item.bank_name,
          accounts: [],
        };

        // Fetch accounts for the current item
        const accounts = await retrieveAccountsByItemId(item.id);

        // Add relevant account details to the bank object
        bank.accounts = accounts.map(account =>
          _.pick(account, [
            'id',
            'name',
            'mask',
            'official_name',
            'current_balance',
            'available_balance',
            'iso_currency_code',
            'type',
            'subtype',
          ])
        );

        return bank;
      })
    );

    const result =
      banksWithAccounts.length > 0
        ? { banks: banksWithAccounts }
        : { banks: [] };
    res.json({ banks: result });
  })
);

module.exports = router;
