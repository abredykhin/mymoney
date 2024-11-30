// Update with your config settings.
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

/**
 * @type { Object.<string, import("knex").Knex.Config> }
 */
module.exports = {
  production: {
    client: 'pg',
    connection: {
      host: process.env.DB_HOST_NAME,
      port: process.env.DB_PORT,
      user: process.env.POSTGRES_USER,
      password: process.env.POSTGRES_PASSWORD,
      database: process.env.DB_NAME,
    },
    migrations: {
      directory: path.join(__dirname, 'migrations'), // Place migration files here
    },
    pool: {
      min: 2,
      max: 10,
    },
  },
  development: {
    client: 'pg',
    connection: {
      host: process.env.DB_HOST_NAME || '127.0.0.1',
      port: process.env.DB_PORT || 5432,
      user: process.env.POSTGRES_USER,
      password: process.env.POSTGRES_PASSWORD,
      database: process.env.DB_NAME || 'mymoney',
    },
    migrations: {
      directory: path.join(__dirname, 'migrations'),
    },
  },
};
