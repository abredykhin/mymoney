const bcrypt = require('bcrypt');
const usersQueries = require('../db/queries/users');
const boom = require('@hapi/boom');

const registerUser = async req => {
  console.log('Registering new user.');

  const { username, password } = req.body;
  if (!(username && password)) {
    throw boom.badRequest('All inputs are required');
  }

  console.log('Received non-empty name & password values.');

  // Checking if the user already exists
  const oldUser = await usersQueries.retrieveUserByUsername(username);
  if (oldUser) {
    throw boom.conflict('User Already Exist. Please Login.');
  }

  console.log('No existing users with same username.');

  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(password, salt);
  console.log(`Hashed password: ${hashedPassword}`);

  const user = await usersQueries.createUser(username, hashedPassword);
  console.log(`New user created with ${username}.`);

  return user;
};

const loginUser = async req => {
  const { username, password } = req.body;
  if (!(username && password)) {
    throw boom.badRequest('All inputs are required.');
  }

  const user = await usersQueries.retrieveUserByUsername(username);
  if (user && (await bcrypt.compare(password, user.password))) {
    return user;
  } else {
    throw boom.unauthorized('User not found!');
  }
};

module.exports = { registerUser, loginUser };
