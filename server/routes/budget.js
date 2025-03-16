const express = require('express');
const _ = require('lodash');

const { retrieveAccountsByItemId } = require('../db/queries/accounts');
const { retrieveItemsByUser } = require('../db/queries/items');
const { asyncWrapper, verifyToken } = require('../middleware');
const logger = require('../utils/logger');
const log = require('../utils/logger')('routes:budget');

const router = express.Router();

router.get(
  '/totalBalance',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const { userId } = req;
    logger.info(`Requesting total balance for user ${userId}`);

    const items = await retrieveItemsByUser(userId);
    let balance = 0;
    let isoCurrencyCode;

    logger.debug(`Got ${items.length} items`);
    for (const item of items) {
      logger.info(`Querying db for accounts for item ${item.id}`);

      const accounts = await retrieveAccountsByItemId(item.id);

      logger.info(`Got ${accounts.length} accounts`);

      for (const account of accounts) {
        let accountBalance;
        switch (account.type) {
          case 'credit':
          case 'loan':
            accountBalance =
              -account.current_balance ?? -account.available_balance;
            logger.info(`Account type is credit/loan`);

            break;
          case 'investment':
          case 'brokerage':
          case 'depository':
          case 'other':
            accountBalance =
              account.current_balance ?? account.available_balance;
            logger.info(`Account type is depository`);

            break;
          default:
            log.info(`Unhandled account type: ${account.type}`);

            continue;
        }

        if (accountBalance !== null && accountBalance !== undefined) {
          balance += accountBalance;
          isoCurrencyCode = account.iso_currency_code;
        }
      }
    }

    logger.info(`Total balance is ${balance}`);

    res.json({ balance: balance, iso_currency_code: isoCurrencyCode });
  })
);

/**
 * This route pulls information about user':
 * -  total balance accross all accounts
 * -  total of all debits accross all user accounts
 * -  total of all credits accross all user accounts
 * -  last 5 transactions
 *
 * @param userId user id in the request body
 * @param forcedRefresh indicates whethere this request is forced refresh. If so, we make a call to Plaid API to refresh user accounts and transactions.
 */
// router.get('summary', verifyToken, asyncWrapper(async (req, res) => {

// });
module.exports = router;
