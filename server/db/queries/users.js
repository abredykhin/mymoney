/**
 * @file Defines the queries for the users table/views.
 */

const db = require('../');
require('util').inspect.defaultOptions.depth = null;

/**
 * Creates a single user.
 *
 * @param {string} username the username of the user.
 * @returns {Object} the new user.
 */
const createUser = async (username, hashedPassword) => {
  const query = {
    // RETURNING is a Postgres-specific clause that returns a list of the inserted items.
    text: 'INSERT INTO users_table (username, password) VALUES ($1, $2) RETURNING *;',
    values: [username, hashedPassword],
  };
  const res = await db.query(query);
  return res.rows[0];
};

/**
 * Removes users and related items, accounts and transactions.
 *
 *
 * @param {string[]} userId the desired user to be deleted.
 */

const deleteUsers = async userId => {
  const query = {
    text: 'DELETE FROM users_table WHERE id = $1;',
    values: [userId],
  };
  await db.query(query);
};

/**
 * Retrieves a single user.
 *
 * @param {number} userId the ID of the user.
 * @returns {Object} a user.
 */
const retrieveUserById = async userId => {
  const query = {
    text: 'SELECT * FROM users WHERE id = $1',
    values: [userId],
  };
  const res = await db.query(query);
  return res.rows[0];
};

/**
 * Retrieves a single user.
 *
 * @param {string} username the username to search for.
 * @returns {Object} a single user.
 */
const retrieveUserByUsername = async username => {
  const query = {
    text: 'SELECT * FROM users WHERE username = $1',
    values: [username],
  };
  const res = await db.query(query);
  return res.rows[0];
};

const retrieveUserByPlaidItemId = async plaidItemId => {
  const query = {
    text: 'SELECT * FROM users WHERE plaid_item_id = $1',
    values: [plaidItemId],
  };
  const res = await db.query(query);
  return res.rows[0];
};

/**
 * Retrieves all users.
 *
 * @returns {Object[]} an array of users.
 */
const retrieveUsers = async () => {
  const query = {
    text: 'SELECT * FROM users',
  };
  const { rows: users } = await db.query(query);
  return users;
};

/**
 * Updates user password.
 *
 * @returns {Object} a user.
 */
const updateUserPassword = async (userId, password) => {
  const query = {
    text: 'UPDATE users SET password = $1 WHERE id = $2 RETURNING *',
    values: [password, userId],
  };
  const res = await db.query(query);
  return res.rows[0];
};

module.exports = {
  createUser,
  deleteUsers,
  retrieveUserById,
  retrieveUserByUsername,
  retrieveUsers,
  updateUserPassword,
};
