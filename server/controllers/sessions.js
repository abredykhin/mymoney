const bcrypt = require('bcrypt');
const sessions = require('../db/queries/sessions');

const initSession = async userId => {
  const token = await bcrypt.genSalt();
  const crsfToken = await bcrypt.genSalt();

  const session = await sessions.createSession(token, crsfToken, userId);
  return session;
};

const expireToken = async token => {
  await sessions.expireToken(token);
};

module.exports = {
  initSession,
  expireToken,
};
