/**
 * @file Defines the queries for the sessions table/views.
 */

const db = require('../');

const createSession = async (token, crsfToken, userId) => {
  const query = {
    text: 'INSERT INTO sessions_table (token, user_id) VALUES ($1, $2, $3)',
    values: [token, userId],
  };
  await db.query(query);
};

const expireToken = async token => {
  const query = {
    text: 'UPDATE sessions_table SET "status" = expired WHERE token = $1;',
    values: [token],
  };
  await db.query(query);
};

module.exports = {
  createSession,
  expireToken,
};
