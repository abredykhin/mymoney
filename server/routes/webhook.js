const express = require('express');
const { asyncWrapper } = require('../middleware');
const syncTransactions = require('../plaid/syncTransactions');
const debug = require('debug')('routes:webhook');
const router = express.Router();

router.post(
  '/webhook',
  asyncWrapper(async (req, res) => {
    try {
      debug('**INCOMING WEBHOOK**');
      console.dir(req.body, { colors: true, depth: null });
      const product = req.body.webhook_type;
      const code = req.body.webhook_code;

      switch (product) {
        case 'ITEM':
          debug('Processing item webhook');
          handleItemWebhook(code, req.body);
          break;
        case 'TRANSACTIONS':
          debug('Processing transactions');
          handleTxnWebhook(code, req.body);
          break;
        default:
          debug(`Can't handle webhook product ${product}`);
          break;
      }
      res.json({ status: 'received' });
    } catch (error) {
      next(error);
    }
  })
);

function handleTxnWebhook(code, requestBody) {
  switch (code) {
    case 'SYNC_UPDATES_AVAILABLE':
      debug('Sync updates available. Starting the sync');
      syncTransactions(requestBody.item_id);
      break;
    // If we're using sync, we don't really need to concern ourselves with the
    // other transactions-related webhooks
    default:
      debug(`Can't handle webhook code ${code}`);
      break;
  }
}

function handleItemWebhook(code, requestBody) {
  switch (code) {
    case 'ERROR':
      // The most common reason for receiving this webhook is because your
      // user's credentials changed and they should run Link in update mode to fix it.
      debug(
        `I received this error: ${requestBody.error.error_message}| should probably ask this user to connect to their bank`
      );
      break;
    case 'LOGIN_REPAIRED':
      debug(
        `Login to (Id: ${requestBody.item_id}) is now repaired and ready to go !`
      );
      break;
    case 'NEW_ACCOUNTS_AVAILABLE':
      debug(
        `There are new accounts available at this Financial Institution! (Id: ${requestBody.item_id}) We may want to ask the user to share them with us`
      );
      break;
    case 'PENDING_EXPIRATION':
    case 'PENDING_DISCONNECT':
      debug(
        `We should tell our user to reconnect their bank with Plaid so there's no disruption to their service`
      );
      break;
    case 'USER_PERMISSION_REVOKED':
    case 'USER_ACCOUNT_REVOKED':
      debug(
        `The user revoked access to this item. We should remove it from our records`
      );
      break;
    case 'WEBHOOK_UPDATE_ACKNOWLEDGED':
      debug(`Hooray! You found the right spot!`);
      break;
    default:
      debug(`Can't handle webhook code ${code}`);
      break;
  }
}

module.exports = router;
