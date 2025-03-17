/**
 * @file Defines the queries for the transactions table.
 */

const { retrieveAccountByPlaidAccountId } = require('./accounts');
const db = require('../');
const debug = require('debug')('db:transactions');
/**
 * Creates or updates multiple transactions.
 *
 * @param {Object[]} transactions an array of transactions.
 */
const createOrUpdateTransactions = async transactions => {
  debug('Storing transactions in db...');

  const client = await db.connect(); // Obtain a single client (connection)
  try {
    await client.query('BEGIN'); // Start transaction

    for (const transaction of transactions) {
      const {
        amount,
        iso_currency_code,
        date,
        authorized_date,
        name,
        merchant_name,
        logo_url,
        website,
        payment_channel,
        transaction_id,
        pending,
        pending_transaction_id: pending_transaction_transaction_id,
      } = transaction;

      // Retrieve the account ID within the same transaction
      const { id } = await retrieveAccountByPlaidAccountId(
        transaction.account_id
      );

      const {
        primary: personal_finance_category = null,
        detailed: personal_finance_subcategory = null,
      } = transaction.personal_finance_category || {};

      // Prepare the SQL query for each transaction
      const query = {
        text: `
    INSERT INTO transactions_table
      (
        account_id,
        amount,
        iso_currency_code,
        date,
        authorized_date,
        name,
        merchant_name,
        logo_url,
        website,
        payment_channel,
        transaction_id,
        personal_finance_category,
        personal_finance_subcategory,
        pending,
        pending_transaction_transaction_id
      )
    VALUES
      ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
    ON CONFLICT (transaction_id) DO UPDATE 
      SET 
        amount = EXCLUDED.amount,
        date = EXCLUDED.date,
        name = EXCLUDED.name,
        merchant_name = EXCLUDED.merchant_name,
        logo_url = EXCLUDED.logo_url,
        website = EXCLUDED.website,
        payment_channel = EXCLUDED.payment_channel,
        personal_finance_category = EXCLUDED.personal_finance_category,
        personal_finance_subcategory = EXCLUDED.personal_finance_subcategory,
        pending = EXCLUDED.pending,
        pending_transaction_transaction_id = EXCLUDED.pending_transaction_transaction_id;
  `,
        values: [
          id,
          amount,
          iso_currency_code,
          date,
          authorized_date || null,
          name,
          merchant_name || null,
          logo_url || null,
          website || null,
          payment_channel,
          transaction_id,
          personal_finance_category || null,
          personal_finance_subcategory || null,
          pending,
          pending_transaction_transaction_id || null, // $15 is the last value
        ],
      };

      // Execute the query within the transaction
      await client.query(query);
    }

    await client.query('COMMIT'); // Commit transaction after all queries succeed
    debug('All transactions stored successfully');
    return { success: true };
  } catch (err) {
    await client.query('ROLLBACK'); // Rollback transaction in case of error
    debug('Error storing transactions, transaction rolled back:', err);
    return { success: false, error: err };
  } finally {
    client.release(); // Release the client back to the pool
  }
};

/**
 * Retrieves all transactions for a single account.
 *
 * @param {number} accountId the ID of the account.
 * @param {limit} limit how many transactions to return
 * @returns {Object[]} an array of transactions.
 */
const retrieveTransactionsByAccountId = async (accountId, limit) => {
  const query = {
    text: 'SELECT * FROM transactions WHERE account_id = $1 ORDER BY date DESC LIMIT $2',
    values: [accountId, limit],
  };
  const { rows: transactions } = await db.query(query);
  return transactions;
};

/**
 * Retrieves all transactions for a single user.
 *
 *
 * @param {number} userId the ID of the user.
 * @param {limit} limit how many transactions to return
 * @returns {Object[]} an array of transactions.
 */
const retrieveTransactionsByUserId = async (userId, limit) => {
  debug(`Running db query for transaction for user ${userId}`);

  const query = {
    text: 'SELECT * FROM transactions WHERE user_id = $1 ORDER BY date DESC LIMIT $2',
    values: [userId, limit],
  };
  const { rows: transactions } = await db.query(query);
  return transactions;
};

/**
 * Retrieves all transactions for a single user.
 *
 *
 * @param {number} userId the ID of the user.
 * @param {limit} limit how many transactions to return
 * @returns {Object[]} an array of transactions.
 */
const retrieveTransactionsByItemId = async (userId, limit) => {
  const query = {
    text: 'SELECT * FROM transactions WHERE item_id = $1 ORDER BY date DESC LIMIT $2',
    values: [itemId, limit],
  };
  const { rows: transactions } = await db.query(query);
  return transactions;
};

/**
 * Removes one or more transactions.
 *
 * @param {string[]} plaidTransactionIds the Plaid IDs of the transactions.
 */
const deleteTransactions = async plaidTransactionIds => {
  const pendingQueries = plaidTransactionIds.map(async transactionId => {
    const query = {
      text: 'DELETE FROM transactions_table WHERE transaction_id = $1',
      values: [transactionId],
    };
    await db.query(query);
  });
  await Promise.all(pendingQueries);
};

module.exports = {
  createOrUpdateTransactions,
  retrieveTransactionsByAccountId,
  retrieveTransactionsByItemId,
  retrieveTransactionsByUserId,
  deleteTransactions,
};
