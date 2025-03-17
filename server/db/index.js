/**
 * @file Defines a connection to the PostgreSQL database, using environment
 * variables for connection information.
 */

const { Pool, types } = require('pg');
require('dotenv').config();

// node-pg returns numerics as strings by default. since we don't expect to
// have large currency values, we'll parse them as floats instead.
types.setTypeParser(1700, val => parseFloat(val));

const { 
  DB_PORT, 
  DB_HOST_NAME, 
  DB_NAME, 
  POSTGRES_USER, 
  POSTGRES_PASSWORD,
  POSTGRES_HOST,
  POSTGRES_PORT
} = process.env;

// Create a connection pool. This generates new connections for every request.
const db = new Pool({
  host: POSTGRES_HOST || DB_HOST_NAME,
  port: POSTGRES_PORT || DB_PORT,
  user: POSTGRES_USER,
  password: POSTGRES_PASSWORD,
  database: DB_NAME,
  max: 5,
  min: 2,
  idleTimeoutMillis: 30000, // close idle clients after 30 second
  connectionTimeoutMillis: 5000, // return an error after 5 second if connection could not be established
});

module.exports = db;
