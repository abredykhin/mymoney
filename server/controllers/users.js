const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const usersQueries = require('../db/queries/users');
const boom = require('@hapi/boom');

const registerUser = async req => {
  console.log('Registering new user.');

  const { username, password } = req.body;
  if (!(username && password)) {
    throw boom.badRequest('All inputs are required');
  }

  // Checking if the user already exists
  const oldUser = await usersQueries.retrieveUserByUsername(username);
  if (oldUser) {
    throw boom.badRequest('User Already Exist. Please Login.');
  }

  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(password, salt);

  const user = await usersQueries.createUser(username, hashedPassword);
  console.log(`New user created with ${username}.`);

  return user;
};

const loginUser = async req => {
  const { username, password } = req.body;
  if (!(username && password)) {
    throw boom.badRequest('User Already Exist. Please Login.');
  }

  const user = await retrieveUserByUsername(username);
  if (user && (await bcrypt.compare(password, user.password))) {
    return user;
  } else {
    throw boom.badRequest('User not found!');
  }
};

module.exports = { registerUser, loginUser };
