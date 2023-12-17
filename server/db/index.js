/**
 * @file Defines a connection to the PostgreSQL database, using environment
 * variables for connection information.
 */

const { Pool, types } = require('pg');
require('dotenv').config();

// node-pg returns numerics as strings by default. since we don't expect to
// have large currency values, we'll parse them as floats instead.
types.setTypeParser(1700, val => parseFloat(val));

const { DB_PORT, DB_HOST_NAME, DB_NAME, POSTGRES_USER, POSTGRES_PASSWORD } =
  process.env;

// Create a connection pool. This generates new connections for every request.
const db = new Pool({
  host: DB_HOST_NAME,
  port: DB_PORT,
  user: POSTGRES_USER,
  password: POSTGRES_PASSWORD,
  database: DB_NAME,
  max: 5,
  min: 2,
  idleTimeoutMillis: 1000, // close idle clients after 1 second
  connectionTimeoutMillis: 1000, // return an error after 1 second if connection could not be established
});

module.exports = db;
