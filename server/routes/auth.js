const express = require('express');
const usersController = require('../controllers/users');
const sessionsController = require('../controllers/sessions');
const utils = require('../utils/sanitize');
const { asyncWrapper } = require('../middleware');
const debug = require('debug')('routes:auth');

const router = express.Router();

router.post(
  '/register',
  asyncWrapper(async (req, res) => {
    debug('Registering new user.');
    const user = await usersController.registerUser(req);
    const session = await sessionsController.initSession(user.id);
    const userToReturn = utils.sanitizeUserObject(user);
    debugg('Registration complete.');

    res.status(200).json({
      user: userToReturn,
      token: session.token,
    });
  })
);

router.post(
  '/login',
  asyncWrapper(async (req, res) => {
    debug('Logging user in.');
    const user = await usersController.loginUser(req);
    debug('Setting up a new sessions');
    const session = await sessionsController.initSession(user.id);
    const userToReturn = utils.sanitizeUserObject(user);

    const returnObj = {
      user: userToReturn,
      token: session.token,
    };

    debug('Login successful.');
    res.status(200).json(returnObj);
  })
);

module.exports = router;
