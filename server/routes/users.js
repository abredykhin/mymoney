const express = require('express');
const usersController = require('../controllers/users');
const sessionsController = require('../controllers/sessions');
const utils = require('../utils');
const { asyncWrapper } = require('../utils/errors');

const router = express.Router();

router.post(
  '/register',
  asyncWrapper(async (req, res) => {
    console.log('Register new user route. Uses updated code!');
    const user = await usersController.registerUser(req);
    const session = await sessionsController.initSession(user.id);
    const userToReturn = utils.sanitizeUserObject(user);
    console.log('Ready to send data back.');

    res.status(200).json({
      user: userToReturn,
      token: session.token,
    });
  })
);

router.post(
  '/login',
  asyncWrapper(async (req, res) => {
    const user = await usersController.loginUser(req);
    const session = await sessionsController.initSession(user.id);
    const userToReturn = utils.sanitizeUserObject(user);

    const returnObj = {
      user: userToReturn,
      token: session.token,
    };

    console.dir(returnObj, { depth: null });

    res.status(200).json(returnObj);
  })
);

module.exports = router;
