/**
 * @file Defines all routes for the Items route.
 */

const express = require('express');
const Boom = require('@hapi/boom');
const {
  createInstitution,
  retrieveItemById,
  retrieveItemByPlaidInstitutionId,
  retrieveAccountsByItemId,
  createItem,
  deleteItem,
  updateItemStatus,
  updateAccountHiddenStatus,
} = require('../db/queries');
const { asyncWrapper, verifyToken } = require('../middleware');
const plaid = require('../plaid/loggingPlaidClient');
const {
  sanitizeAccounts,
  sanitizeItem,
  sanitizeItems,
  isValidItemStatus,
  validItemStatuses,
} = require('../utils/sanitize');
const syncTransactions = require('../controllers/transactions');
const debug = require('debug')('routes:items');
const router = express.Router();
const logger = require('../utils/logger');

/**
 * First exchanges a public token for a private token via the Plaid API
 * and then stores the newly created item in the DB.
 *
 * @param {string} publicToken public token returned from the onSuccess call back in Link.
 * @param {string} institutionId the Plaid institution ID of the new item.
 * @param {string} userId the Plaid user ID of the active user.
 */
router.post(
  '/',
  verifyToken,
  asyncWrapper(async (req, res) => {
    debug('Creating a new item');
    logger.info('Creating a new item');
    const { publicToken, institutionId } = req.body;
    const userId = req.userId;

    // prevent duplicate items for the same institution per user.
    debug('Checking for duplicate item...');
    logger.info('Checking for duplicate item...');
    const existingItem = await retrieveItemByPlaidInstitutionId(
      institutionId,
      userId
    );

    debug('Asking Plaid for info on institution...');
    logger.info('Asking Plaid for info on institution...');
    const institutionResponse = await plaid.client.institutionsGetById({
      client_id: '',
      secret: '',
      institution_id: institutionId,
      country_codes: ['US'],
      options: {
        include_optional_metadata: true,
      },
    });

    debug(
      `Received institution info for ${institutionResponse.data.institution.name}. Storing in database...`
    );
    logger.info(
      `Received institution info for ${institutionResponse.data.institution.name}. Storing in database...`
    );

    await createInstitution(
      institutionResponse.data.institution.institution_id,
      institutionResponse.data.institution.name,
      institutionResponse.data.institution.primary_color,
      institutionResponse.data.institution.url,
      institutionResponse.data.institution.logo
    );

    debug('Exchanging tokens with Plaid...');
    logger.info('Exchanging tokens with Plaid...');

    // exchange the public token for a private access token and store with the item.
    const response = await plaid.itemPublicTokenExchange({
      public_token: publicToken,
    });
    const accessToken = response.data.access_token;
    const itemId = response.data.item_id;
    debug(`Storing item ${itemId} info in db...`);
    logger.info('Storing item info in db...');

    // store the item in the database.
    const newItem = await createItem(
      institutionId,
      accessToken,
      itemId,
      userId,
      institutionResponse.data.institution.name
    );

    debug(`Syncing item ${itemId} transactions...`);
    logger.info('Syncing item transactions...');

    await syncTransactions(itemId).then(() => {
      // Notify frontend to reflect any transactions changes.
      // TODO:
      //req.io.emit('NEW_TRANSACTIONS_DATA', { itemId: newItem.id });
    });

    debug('Item is ready. Sending it back to client.');
    logger.info('Item is ready. Sending it back to client.');
    res.json(sanitizeItem(newItem));
  })
);

/**
 * Retrieves a single item.
 *
 * @param {string} itemId the ID of the item.
 * @returns {Object[]} an array containing a single item.
 */
router.get(
  '/:itemId',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const { itemId } = req.params;
    const item = await retrieveItemById(itemId);
    res.json(sanitizeItems(item));
  })
);

/**
 * Updates a single item.
 *
 * @param {string} itemId the ID of the item.
 * @returns {Object[]} an array containing a single item.
 */
router.put(
  '/:itemId',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const { itemId } = req.params;
    const { status } = req.body;

    if (status) {
      if (!isValidItemStatus(status)) {
        throw new Boom(
          'Cannot set item status. Please use an accepted value.',
          {
            statusCode: 400,
            acceptedValues: [validItemStatuses.values()],
          }
        );
      }
      await updateItemStatus(itemId, status);
      const item = await retrieveItemById(itemId);
      res.json(sanitizeItems(item));
    } else {
      throw new Boom('You must provide updated item information.', {
        statusCode: 400,
        acceptedKeys: ['status'],
      });
    }
  })
);

/**
 * Deletes a single item and related accounts and transactions.
 * Also removes the item from the Plaid API
 * access_token associated with the Item is no longer valid
 * https://plaid.com/docs/#remove-item-request
 * @param {string} itemId the ID of the item.
 * @returns status of 204 if successful
 */
router.delete(
  '/:itemId',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const { itemId } = req.params;
    const { plaid_access_token: accessToken } = await retrieveItemById(itemId);
    /* eslint-disable camelcase */
    try {
      const response = await plaid.itemRemove({
        access_token: accessToken,
      });
      const removed = response.data.removed;
      const status_code = response.data.status_code;
    } catch (error) {
      if (!removed)
        throw new Boom('Item could not be removed in the Plaid API.', {
          statusCode: status_code,
        });
    }
    await deleteItem(itemId);

    res.sendStatus(204);
  })
);

/**
 * Retrieves all accounts associated with a single item.
 *
 * @param {string} itemId the ID of the item.
 * @returns {Object[]} an array of accounts.
 */
router.get(
  '/:itemId/accounts',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const { itemId } = req.params;
    const accounts = await retrieveAccountsByItemId(itemId);
    res.json(sanitizeAccounts(accounts));
  })
);

/**
 * -- This endpoint will only work in the sandbox enviornment --
 * Forces an Item into an ITEM_LOGIN_REQUIRED (bad) error state.
 * An ITEM_LOGIN_REQUIRED webhook will be fired after a call to this endpoint.
 * https://plaid.com/docs/#managing-item-states
 *
 * @param {string} itemId the Plaid ID of the item.
 * @return {Object} the response from the Plaid API.
 */
router.post(
  '/sandbox/item/reset_login',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const { itemId } = req.body;
    const { plaid_access_token: accessToken } = await retrieveItemById(itemId);
    const resetResponse = await plaid.sandboxItemResetLogin({
      access_token: accessToken,
    });
    res.json(resetResponse.data);
  })
);

/**
 * Updates the hidden status of an account
 * 
 * @param {string} accountId the ID of the account
 * @param {boolean} hidden the new hidden status
 * @returns {Object} the updated account
 */
router.put(
  '/accounts/:accountId/hidden',
  verifyToken,
  asyncWrapper(async (req, res) => {
    const { accountId } = req.params;
    const { hidden } = req.body;
    
    if (hidden === undefined) {
      throw new Boom('Missing hidden parameter', {
        statusCode: 400,
      });
    }
    
    if (typeof hidden !== 'boolean') {
      throw new Boom('Hidden parameter must be a boolean', {
        statusCode: 400,
      });
    }
    
    debug(`Updating account ${accountId} hidden status to ${hidden}`);
    logger.info(`Updating account ${accountId} hidden status to ${hidden}`);
    
    const updatedAccount = await updateAccountHiddenStatus(accountId, hidden);
    
    if (!updatedAccount) {
      throw new Boom('Account not found', {
        statusCode: 404,
      });
    }
    
    res.json(sanitizeAccounts([updatedAccount])[0]);
  })
);

module.exports = router;
