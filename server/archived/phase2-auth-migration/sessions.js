/**
 * @file Defines the queries for the sessions table/views.
 */

const db = require('../');
require('util').inspect.defaultOptions.depth = null;

const createSession = async (token, userId) => {
  const query = {
    text: 'INSERT INTO sessions_table (token, user_id) VALUES ($1, $2) RETURNING token;',
    values: [token, userId],
  };
  const res = await db.query(query);
  return res.rows[0];
};

const expireToken = async token => {
  const query = {
    text: 'UPDATE sessions_table SET "status" = expired WHERE token = $1;',
    values: [token],
  };
  return await db.query(query);
};

const lookupToken = async token => {
  const query = {
    text: 'SELECT user_id FROM sessions_table WHERE token = $1;',
    values: [token],
  };

  const res = await db.query(query);
  return res.rows[0];
};

module.exports = {
  createSession,
  expireToken,
  lookupToken,
};
