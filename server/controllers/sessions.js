const crypto = require('crypto');
const sessions = require('../db/queries/sessions');
const debug = require('debug')('controllers:sessions');

const initSession = async userId => {
  debug(`Generating new session for user ${userId}`);
  const token = crypto.randomBytes(64).toString('hex');
  debug(`Token generated. Storing session in db.`);

  const session = await sessions.createSession(token, userId);
  debug('Session created.');
  return session;
};

const expireToken = async token => {
  await sessions.expireToken(token);
};

module.exports = {
  initSession,
  expireToken,
};
