/**
 * @file Defines the route for link token creation.
 */

const { asyncWrapper, verifyToken } = require('../middleware');

const express = require('express');
const plaid = require('../plaid/loggingPlaidClient');
const { retrieveItemById } = require('../db/queries');

const router = express.Router();

router.post(
  '/',
  verifyToken,
  asyncWrapper(async (req, res) => {
    console.log('Requesting Link token...');
    try {
      const userId = req.userId;
      const { itemId } = req.body;
      let accessToken = null;
      let products = ['transactions']; // must include transactions in order to receive transactions webhooks
      if (itemId != null) {
        // for the link update mode, include access token and an empty products array
        const itemIdResponse = await retrieveItemById(itemId);
        accessToken = itemIdResponse.plaid_access_token;
        products = [];
      }

      const linkTokenParams = {
        user: {
          // This should correspond to a unique id for the current user.
          client_user_id: 'uniqueId' + userId,
        },
        client_name: 'BabloApp',
        products,
        country_codes: ['US'],
        language: 'en',
        webhook: 'https://babloapp.com/plaid/webhook',
        access_token: accessToken,
        redirect_uri: 'https://babloapp.com/plaid/redirect/index.html',
      };

      console.log('Talking to plaid server to get token...');
      const createResponse = await plaid.linkTokenCreate(linkTokenParams);
      console.log('Got token from plaid server.');
      res.json(createResponse.data);
    } catch (err) {
      console.log('error while fetching client token', err.response.data);
      return res.json(err.response.data);
    }
  })
);

module.exports = router;
