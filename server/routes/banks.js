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
  '/accounts',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const userId = req.userId;
    console.log(`Querying db for items for user ${userId}`);
    const items = await retrieveItemsByUser(userId);

    console.log(`Got ${items.length} banks from db`);

    const banksWithAccounts = await Promise.all(
      items.map(async item => {
        const bank = {
          id: item.id,
          bank_name: item.bank_name,
          accounts: [],
        };

        console.log(`Querying db for accounts at bank ${bank.id}`);

        // Fetch accounts for the current item
        const accounts = await retrieveAccountsByItemId(item.id);
        console.log(`Got ${accounts.length} accounts`);

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
            'updated_at',
            'created_at',
          ])
        );

        console.log(`Processed accounts`);
        return bank;
      })
    );

    console.log(`Checking the result`);
    const result = banksWithAccounts.length > 0 ? banksWithAccounts : [];

    console.log(`Sending the response to client`);
    console.log(JSON.stringify(result, null, 2));
    res.json({ banks: result });
  })
);

module.exports = router;
