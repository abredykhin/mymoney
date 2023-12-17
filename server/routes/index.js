const express = require('express');
const { registerUser, loginUser } = require('../controllers/users');
const Boom = require('@hapi/boom');

const noAuthRouter = express.Router();
const authRouter = express.Router();

noAuthRouter.post('/users', registerUser);
noAuthRouter.post('/users/login', loginUser);

/**
 * Throws a 404 not found error for all requests.
 */
noAuthRouter.get('*', (req, res) => {
  throw new Boom('not found', { statusCode: 404 });
});

module.exports = { noAuthRouter, authRouter };
