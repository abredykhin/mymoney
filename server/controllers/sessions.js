const crypto = require('crypto');
const sessions = require('../db/queries/sessions');
require('util').inspect.defaultOptions.depth = null;

const initSession = async userId => {
  console.log(`Generating new session for user ${userId}`);
  const token = crypto.randomBytes(64).toString('hex');
  console.log(`Generated new token: ${token}`);
  const crsfToken = crypto.randomBytes(64).toString('hex');

  const session = await sessions.createSession(token, crsfToken, userId);
  console.log('Created new session');
  console.log(session);
  return session;
};

const expireToken = async token => {
  await sessions.expireToken(token);
};

module.exports = {
  initSession,
  expireToken,
};
