const express = require('express');
const { asyncWrapper } = require('../middleware');
const syncTransactions = require('../plaid/syncTransactions');
const debug = require('debug')('routes:webhook');
const router = express.Router();
const logger = require('../utils/logger');

router.post(
  '/webhook',
  asyncWrapper(async (req, res) => {
    debug('**INCOMING WEBHOOK**');
    logger.info('**INCOMING WEBHOOK**');

    const product = req.body.webhook_type;
    const code = req.body.webhook_code;

    switch (product) {
      case 'ITEM':
        debug('Processing item webhook');
        logger.info('Processing item webhook');
        handleItemWebhook(code, req.body);
        break;
      case 'TRANSACTIONS':
        debug('Processing transactions');
        logger.info('Processing transactions');
        handleTxnWebhook(code, req.body);
        break;
      default:
        debug(`Can't handle webhook product ${product}`);
        logger.error(`Can't handle webhook product ${product}`);
        break;
    }
    res.json({ status: 'received' });
  })
);

function handleTxnWebhook(code, requestBody) {
  switch (code) {
    case 'SYNC_UPDATES_AVAILABLE':
      debug('Sync updates available. Starting the sync');
      logger.info('Transactions sync updates available. Starting the sync');
      syncTransactions(requestBody.plaidItemId);
      break;
    case 'DEFAULT_UPDATE':
    case 'INITIAL_UPDATE':
    case 'HISTORICAL_UPDATE':
      /* ignore - not needed if using sync endpoint + webhook */
      logger.info('Ignoring tnx webhook');
      break;
    default:
      debug(`Can't handle webhook code ${code}`);
      logger.error(`Can't handle webhook code ${code}`);
      break;
  }
}

function handleItemWebhook(code, requestBody) {
  switch (code) {
    case 'ERROR':
      // The most common reason for receiving this webhook is because your
      // user's credentials changed and they should run Link in update mode to fix it.
      debug(
        `Got item error: ${requestBody.error.error_message}| should probably ask this user to connect to their bank`
      );
      logger.error(
        `Got item error: ${requestBody.error.error_message}| should probably ask this user to connect to their bank`
      );
      break;
    case 'LOGIN_REPAIRED':
      debug(
        `Login to (Id: ${requestBody.item_id}) is now repaired and ready to go !`
      );
      logger.info(
        `Login to (Id: ${requestBody.item_id}) is now repaired and ready to go !`
      );
      break;
    case 'NEW_ACCOUNTS_AVAILABLE':
      debug(
        `There are new accounts available at this Financial Institution! (Id: ${requestBody.item_id}) We may want to ask the user to share them with us`
      );
      logger.info(
        `There are new accounts available at this Financial Institution! (Id: ${requestBody.item_id}) We may want to ask the user to share them with us`
      );
      break;
    case 'PENDING_EXPIRATION':
    case 'PENDING_DISCONNECT':
      debug(
        `We should tell our user to reconnect their bank with Plaid so there's no disruption to their service`
      );
      logger.info(
        `We should tell our user to reconnect their bank with Plaid so there's no disruption to their service`
      );
      break;
    case 'USER_PERMISSION_REVOKED':
    case 'USER_ACCOUNT_REVOKED':
      debug(
        `The user revoked access to this item. We should remove it from our records`
      );
      logger.info(
        `The user revoked access to this item. We should remove it from our records`
      );
      break;
    case 'WEBHOOK_UPDATE_ACKNOWLEDGED':
      debug(`Hooray! You found the right spot!`);
      logger.info(`Hooray! You found the right spot!`);
      break;
    default:
      debug(`Can't handle webhook code ${code}`);
      logger.error(`Can't handle webhook code ${code}`);
      break;
  }
}

module.exports = router;
