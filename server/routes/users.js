const express = require('express');
const usersController = require('../controllers/users');
const sessionsController = require('../controllers/sessions');
const utils = require('../utils');

const router = express.Router();

router.post('/register', async (req, res) => {
  const user = usersController.registerUser(req);
  const session = sessionsController.initSession(user.id);
  const userToReturn = utils.sanitizeUsers(user);

  return res.status(200).json({
    user: userToReturn,
    token: session.token,
  });
});

router.post('/login', async (req, res) => {
  const user = usersController.loginUser(req);
  const session = sessionsController.initSession(user.id);
  const userToReturn = utils.sanitizeUsers(user);

  return res.status(200).json({
    user: userToReturn,
    token: session.token,
  });
});

module.exports = router;
