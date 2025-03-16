const crypto = require('crypto');
const sessions = require('../db/queries/sessions');
const log = require('../utils/logger')('controllers:sessions');

const initSession = async userId => {
  log.info(`Generating new session for user ${userId}`);
  const token = crypto.randomBytes(64).toString('hex');
  log.info(`Token generated. Storing session in db.`);

  const session = await sessions.createSession(token, userId);
  log.info('Session created.');
  return session;
};

const expireToken = async token => {
  await sessions.expireToken(token);
};

module.exports = {
  initSession,
  expireToken,
};
