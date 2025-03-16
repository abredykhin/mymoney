const bcrypt = require('bcrypt');
const usersQueries = require('../db/queries/users');
const Boom = require('@hapi/boom');
const log = require('../utils/logger')('controllers:users');

const registerUser = async req => {
  log.info('Registering a new user');
  const { username, password } = req.body;
  if (!(username && password)) {
    log.error(`Missing username or password.`);
    throw Boom.badRequest('All inputs are required!');
  }

  log.info('Received non-empty name & password values.');

  // Checking if the user already exists
  const oldUser = await usersQueries.retrieveUserByUsername(username);
  if (oldUser) {
    log.error(`User already exists.`);
    throw Boom.conflict('User Already Exist. Please Login.');
  }

  log.info('No existing users with same username. Hashing password');
  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(password, salt);

  log.info(`Password hashed. Storing user in db...`);
  const user = await usersQueries.createUser(username, hashedPassword);

  log.info(`New user created with ${username}.`);
  return user;
};

const loginUser = async req => {
  log.info('Attempting to login user.');
  const { username, password } = req.body;
  if (!(username && password)) {
    log.error('Missing username or password.');
    throw Boom.badRequest('All inputs are required.');
  }

  log.info('Looking up user in db...');
  const user = await usersQueries.retrieveUserByUsername(username);
  if (user && (await bcrypt.compare(password, user.password))) {
    log.info('User found, and the password is correct.');
    return user;
  } else {
    log.error('User not found or password is incorrect');
    throw Boom.unauthorized('No such user or wrong password!');
  }
};

const debugChangePassword = async req => {
  log.info('Attempting to change user password.');
  const { username, newPassword } = req.body;
  if (!(username && newPassword)) {
    log.error('Missing username or password.');
    throw Boom.badRequest('All inputs are required.');
  }
  log.info('Looking up user in db...');
  const user = await usersQueries.retrieveUserByUsername(username);
  if (user) {
    log.info('User found, hashing new password...');
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);
    log.info('Password hashed. Updating user in db...');
    const updatedUser = await usersQueries.updateUserPassword(
      user.id,
      hashedPassword
    );
    log.info('Password updated.');
    return updatedUser;
  } else {
    log.error('User not found');
    throw Boom.unauthorized('No such user!');
  }
};

module.exports = { registerUser, loginUser, debugChangePassword };
