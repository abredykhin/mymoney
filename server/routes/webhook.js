const express = require('express');
const { asyncWrapper } = require('../middleware');
const syncTransactions = require('../controllers/transactions');

const router = express.Router();
const logger = require('../utils/logger')('routes:webhook');

router.post(
  '/webhook',
  asyncWrapper(async (req, res) => {
    logger.info('**INCOMING WEBHOOK**');

    const product = req.body.webhook_type;
    const code = req.body.webhook_code;

    switch (product) {
      case 'ITEM':
        logger.info('Processing item webhook');
        handleItemWebhook(code, req.body);
        break;
      case 'TRANSACTIONS':
        logger.info('Processing transactions');
        handleTxnWebhook(code, req.body);
        break;
      default:
        logger.error(`Can't handle webhook product ${product}`);

        break;
    }
    res.json({ status: 'received' });
  })
);

function handleTxnWebhook(code, requestBody) {
  switch (code) {
    case 'SYNC_UPDATES_AVAILABLE':
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
      logger.error(`Can't handle webhook code ${code}`);

      break;
  }
}

function handleItemWebhook(code, requestBody) {
  switch (code) {
    case 'ERROR':
      // The most common reason for receiving this webhook is because your
      // user's credentials changed and they should run Link in update mode to fix it.
      logger.error(
        `Got item error: ${requestBody.error.error_message}| should probably ask this user to connect to their bank`
      );

      break;
    case 'LOGIN_REPAIRED':
      logger.info(
        `Login to (Id: ${requestBody.item_id}) is now repaired and ready to go !`
      );

      break;
    case 'NEW_ACCOUNTS_AVAILABLE':
      logger.info(
        `There are new accounts available at this Financial Institution! (Id: ${requestBody.item_id}) We may want to ask the user to share them with us`
      );

      break;
    case 'PENDING_EXPIRATION':
    case 'PENDING_DISCONNECT':
      logger.info(
        `We should tell our user to reconnect their bank with Plaid so there's no disruption to their service`
      );

      break;
    case 'USER_PERMISSION_REVOKED':
    case 'USER_ACCOUNT_REVOKED':
      logger.info(
        `The user revoked access to this item. We should remove it from our records`
      );

      break;
    case 'WEBHOOK_UPDATE_ACKNOWLEDGED':
      logger.info(`Hooray! You found the right spot!`);

      break;
    default:
      break;
  }
}

module.exports = router;
