const express = require('express');
const _ = require('lodash');

const { retrieveAccountsByItemId } = require('../db/queries/accounts');
const { retrieveItemsByUser } = require('../db/queries/items');
const { retrieveInstitutionById } = require('../db/queries/institutions');
const { asyncWrapper, verifyToken } = require('../middleware');
const logger = require('../utils/logger')('routes:banks');

const router = express.Router();

/**
 * Retrieves all banks and accounts associated with a single user.
 */
router.get(
  '/accounts',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const { userId } = req;
    logger.info(`Querying db for items for user ${userId}`);

    const items = await retrieveItemsByUser(userId);

    logger.info(`Got ${items.length} banks from db. Processing...`);

    const banksWithAccounts = await Promise.all(
      items.map(async item => {
        const bank = {
          id: item.id,
          bank_name: item.bank_name,
          accounts: [],
        };

        logger.info('Looking up associated institution');

        const institution = await retrieveInstitutionById(
          item.plaid_institution_id
        );
        bank.logo = institution.logo;
        bank.primary_color = institution.primary_color;

        logger.info(`Looking up accounts at bank ${bank.id}`);

        // Fetch accounts for the current item
        const accounts = await retrieveAccountsByItemId(item.id);
        logger.info(`Got ${accounts.length} accounts`);

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

        logger.info('Account processed');
        return bank;
      })
    );

    const result = banksWithAccounts.length > 0 ? banksWithAccounts : [];

    logger.info('Accounts ready. Sending the result to client');

    res.json({ banks: result });
  })
);

module.exports = router;
