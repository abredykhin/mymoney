const bcrypt = require('bcrypt');
const usersQueries = require('../db/queries/users');
const Boom = require('@hapi/boom');
const debug = require('debug')('controllers:users');

const registerUser = async req => {
  debug('Registering a new user');
  const { username, password } = req.body;
  if (!(username && password)) {
    debug(`Missing username or password.`);
    throw Boom.badRequest('All inputs are required!');
  }

  debug('Received non-empty name & password values.');

  // Checking if the user already exists
  const oldUser = await usersQueries.retrieveUserByUsername(username);
  if (oldUser) {
    debug(`User already exists.`);
    throw Boom.conflict('User Already Exist. Please Login.');
  }

  debug('No existing users with same username. Hashing password');
  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(password, salt);

  debug(`Password hashed. Storing user in db...`);
  const user = await usersQueries.createUser(username, hashedPassword);

  debug(`New user created with ${username}.`);
  return user;
};

const loginUser = async req => {
  debug('Attempting to login user.');
  const { username, password } = req.body;
  if (!(username && password)) {
    debug('Missing username or password.');
    throw Boom.badRequest('All inputs are required.');
  }

  debug('Looking up user in db...');
  const user = await usersQueries.retrieveUserByUsername(username);
  if (user && (await bcrypt.compare(password, user.password))) {
    debug('User found, and the password is correct.');
    return user;
  } else {
    debug('User not found or password is incorrect');
    throw Boom.unauthorized('No such user or wrong password!');
  }
};

const debugChangePassword = async req => {
  debug('Attempting to change user password.');
  const { username, newPassword } = req.body;
  if (!(username && newPassword)) {
    debug('Missing username or password.');
    throw Boom.badRequest('All inputs are required.');
  }
  debug('Looking up user in db...');
  const user = await usersQueries.retrieveUserByUsername(username);
  if (user) {
    debug('User found, hashing new password...');
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);
    debug('Password hashed. Updating user in db...');
    const updatedUser = await usersQueries.updateUserPassword(
      username,
      hashedPassword
    );
    debug('Password updated.');
    return updatedUser;
  } else {
    debug('User not found');
    throw Boom.unauthorized('No such user!');
  }
};

module.exports = { registerUser, loginUser };
