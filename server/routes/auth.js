const express = require('express');
const usersController = require('../controllers/users');
const sessionsController = require('../controllers/sessions');
const utils = require('../utils/sanitize');
const { asyncWrapper } = require('../middleware');

const logger = require('../utils/logger')('routes:auth');

const router = express.Router();

router.post(
  '/register',
  asyncWrapper(async (req, res) => {
    logger.info('Registering new user.');
    const user = await usersController.registerUser(req);
    const session = await sessionsController.initSession(user.id);
    const userToReturn = utils.sanitizeUserObject(user);
    logger.info('Registration complete.');

    res.status(200).json({
      user: userToReturn,
      token: session.token,
    });
  })
);

router.post(
  '/login',
  asyncWrapper(async (req, res) => {
    logger.info('Logging user in.');
    const user = await usersController.loginUser(req);
    logger.info('Setting up a new session');
    const session = await sessionsController.initSession(user.id);
    const userToReturn = utils.sanitizeUserObject(user);

    const returnObj = {
      user: userToReturn,
      token: session.token,
    };

    logger.info('Login successful.');
    res.status(200).json(returnObj);
  })
);

if (process.env.NODE_ENV === 'development') {
  router.post(
    `/debug-change-password`,
    asyncWrapper(async (req, res) => {
      logger.info('Changing user password.');
      const user = await usersController.debugChangePassword(req);
      const userToReturn = utils.sanitizeUserObject(user);
      logger.info('Password changed.');
      res.status(200).json(userToReturn);
    })
  );
}

module.exports = router;
