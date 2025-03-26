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
 * Retrieves transactions for a single account with cursor-based pagination and optional filtering.
 *
 * @param {number} accountId The ID of the account.
 * @param {Object} options Pagination and filtering options.
 * @param {number} options.limit How many transactions to return (default: 50).
 * @param {string} options.cursor Pagination cursor in format "date:id" (optional).
 * @param {Object} options.filters Filter criteria (optional).
 * @param {string} options.filters.category Filter by personal finance category.
 * @param {string} options.filters.startDate Filter transactions on or after this date.
 * @param {string} options.filters.endDate Filter transactions on or before this date.
 * @param {string} options.filters.search Search term for transaction name or merchant name.
 * @returns {Object} Object containing transactions array and pagination metadata.
 */
const retrieveTransactionsByAccountId = async (accountId, options = {}) => {
  const { limit = 50, cursor = null, filters = {} } = options;
  
  // Parse cursor if present
  let cursorDate = null;
  let cursorId = null;
  
  if (cursor) {
    try {
      const [dateStr, idStr] = cursor.split(':');
      cursorDate = dateStr;
      cursorId = parseInt(idStr, 10);
    } catch (err) {
      debug(`Invalid cursor format: ${cursor}`);
    }
  }
  
  // Build query conditions and parameters
  let conditions = ['account_id = $1'];
  let params = [accountId];
  let paramCount = 1;
  
  // Add filter conditions
  if (filters.category) {
    paramCount++;
    conditions.push(`personal_finance_category = $${paramCount}`);
    params.push(filters.category);
  }
  
  if (filters.startDate) {
    paramCount++;
    conditions.push(`date >= $${paramCount}`);
    params.push(filters.startDate);
  }
  
  if (filters.endDate) {
    paramCount++;
    conditions.push(`date <= $${paramCount}`);
    params.push(filters.endDate);
  }
  
  if (filters.search) {
    paramCount++;
    const searchParam = `%${filters.search}%`;
    conditions.push(`(name ILIKE $${paramCount} OR merchant_name ILIKE $${paramCount})`);
    params.push(searchParam);
  }
  
  // Add cursor condition if present
  if (cursorDate && cursorId) {
    conditions.push(`(date < $${paramCount+1} OR (date = $${paramCount+1} AND id < $${paramCount+2}))`);
    params.push(cursorDate, cursorId);
    paramCount += 2;
  }
  
  // Add limit parameter
  paramCount++;
  
  // Build the complete query
  const query = {
    text: `
      SELECT * FROM transactions 
      WHERE ${conditions.join(' AND ')} 
      ORDER BY date DESC, id DESC 
      LIMIT $${paramCount}
    `,
    values: [...params, limit],
  };
  
  const { rows: transactions } = await db.query(query);
  
  // Generate next cursor
  let nextCursor = null;
  if (transactions.length > 0) {
    const lastTx = transactions[transactions.length - 1];
    nextCursor = `${lastTx.date}:${lastTx.id}`;
  }
  
  // Get total count for this filter set (for pagination metadata)
  const countConditions = conditions.filter(c => !c.includes('(date <'));
  const countParams = params.filter((_, i) => i < (cursorDate && cursorId ? paramCount - 3 : paramCount - 1));
  
  const countQuery = {
    text: `SELECT COUNT(*) FROM transactions WHERE ${countConditions.join(' AND ')}`,
    values: countParams,
  };
  
  const { rows: countResult } = await db.query(countQuery);
  const totalCount = parseInt(countResult[0].count, 10);
  
  // For backward compatibility, return just the transactions array if no filtering is applied
  if (!cursor && !Object.keys(filters).length) {
    return transactions;
  }
  
  // Return enhanced result with pagination metadata
  return {
    transactions,
    pagination: {
      totalCount,
      limit,
      hasMore: transactions.length === limit,
      nextCursor
    }
  };
};

/**
 * Retrieves transactions for a single user with cursor-based pagination and optional filtering.
 *
 * @param {number} userId The ID of the user.
 * @param {Object} options Pagination and filtering options.
 * @param {number} options.limit How many transactions to return (default: 50).
 * @param {string} options.cursor Pagination cursor in format "date:id" (optional).
 * @param {Object} options.filters Filter criteria (optional).
 * @param {string} options.filters.category Filter by personal finance category.
 * @param {string} options.filters.startDate Filter transactions on or after this date.
 * @param {string} options.filters.endDate Filter transactions on or before this date.
 * @param {string} options.filters.search Search term for transaction name or merchant name.
 * @returns {Object} Object containing transactions array and pagination metadata.
 */
const retrieveTransactionsByUserId = async (userId, options = {}) => {
  debug(`Running db query for transaction for user ${userId}`);
  
  // For backward compatibility
  if (typeof options === 'number') {
    const limit = options;
    const query = {
      text: 'SELECT * FROM transactions WHERE user_id = $1 ORDER BY date DESC LIMIT $2',
      values: [userId, limit],
    };
    const { rows: transactions } = await db.query(query);
    return transactions;
  }
  
  const { limit = 50, cursor = null, filters = {} } = options;
  
  // Parse cursor if present
  let cursorDate = null;
  let cursorId = null;
  
  if (cursor) {
    try {
      const [dateStr, idStr] = cursor.split(':');
      cursorDate = dateStr;
      cursorId = parseInt(idStr, 10);
    } catch (err) {
      debug(`Invalid cursor format: ${cursor}`);
    }
  }
  
  // Build query conditions and parameters
  let conditions = ['user_id = $1'];
  let params = [userId];
  let paramCount = 1;
  
  // Add filter conditions
  if (filters.category) {
    paramCount++;
    conditions.push(`personal_finance_category = $${paramCount}`);
    params.push(filters.category);
  }
  
  if (filters.startDate) {
    paramCount++;
    conditions.push(`date >= $${paramCount}`);
    params.push(filters.startDate);
  }
  
  if (filters.endDate) {
    paramCount++;
    conditions.push(`date <= $${paramCount}`);
    params.push(filters.endDate);
  }
  
  if (filters.search) {
    paramCount++;
    const searchParam = `%${filters.search}%`;
    conditions.push(`(name ILIKE $${paramCount} OR merchant_name ILIKE $${paramCount})`);
    params.push(searchParam);
  }
  
  // Add cursor condition if present
  if (cursorDate && cursorId) {
    conditions.push(`(date < $${paramCount+1} OR (date = $${paramCount+1} AND id < $${paramCount+2}))`);
    params.push(cursorDate, cursorId);
    paramCount += 2;
  }
  
  // Add limit parameter
  paramCount++;
  
  // Build the complete query
  const query = {
    text: `
      SELECT * FROM transactions 
      WHERE ${conditions.join(' AND ')} 
      ORDER BY date DESC, id DESC 
      LIMIT $${paramCount}
    `,
    values: [...params, limit],
  };
  
  const { rows: transactions } = await db.query(query);
  
  // Generate next cursor
  let nextCursor = null;
  if (transactions.length > 0) {
    const lastTx = transactions[transactions.length - 1];
    nextCursor = `${lastTx.date}:${lastTx.id}`;
  }
  
  // Get total count for this filter set (for pagination metadata)
  const countConditions = conditions.filter(c => !c.includes('(date <'));
  const countParams = params.filter((_, i) => i < (cursorDate && cursorId ? paramCount - 3 : paramCount - 1));
  
  const countQuery = {
    text: `SELECT COUNT(*) FROM transactions WHERE ${countConditions.join(' AND ')}`,
    values: countParams,
  };
  
  const { rows: countResult } = await db.query(countQuery);
  const totalCount = parseInt(countResult[0].count, 10);
  
  // For backward compatibility, return just the transactions array if no filtering is applied
  if (!cursor && !Object.keys(filters).length) {
    return transactions;
  }
  
  // Return enhanced result with pagination metadata
  return {
    transactions,
    pagination: {
      totalCount,
      limit,
      hasMore: transactions.length === limit,
      nextCursor
    }
  };
};

/**
 * Retrieves transactions for a single item with cursor-based pagination and optional filtering.
 *
 * @param {number} itemId The ID of the item.
 * @param {Object} options Pagination and filtering options.
 * @param {number} options.limit How many transactions to return (default: 50).
 * @param {string} options.cursor Pagination cursor in format "date:id" (optional).
 * @param {Object} options.filters Filter criteria (optional).
 * @param {string} options.filters.category Filter by personal finance category.
 * @param {string} options.filters.startDate Filter transactions on or after this date.
 * @param {string} options.filters.endDate Filter transactions on or before this date.
 * @param {string} options.filters.search Search term for transaction name or merchant name.
 * @returns {Object} Object containing transactions array and pagination metadata.
 */
const retrieveTransactionsByItemId = async (itemId, options = {}) => {
  // For backward compatibility
  if (typeof options === 'number') {
    const limit = options;
    const query = {
      text: 'SELECT * FROM transactions WHERE item_id = $1 ORDER BY date DESC LIMIT $2',
      values: [itemId, limit],
    };
    const { rows: transactions } = await db.query(query);
    return transactions;
  }
  
  const { limit = 50, cursor = null, filters = {} } = options;
  
  // Parse cursor if present
  let cursorDate = null;
  let cursorId = null;
  
  if (cursor) {
    try {
      const [dateStr, idStr] = cursor.split(':');
      cursorDate = dateStr;
      cursorId = parseInt(idStr, 10);
    } catch (err) {
      debug(`Invalid cursor format: ${cursor}`);
    }
  }
  
  // Build query conditions and parameters
  let conditions = ['item_id = $1'];
  let params = [itemId];
  let paramCount = 1;
  
  // Add filter conditions
  if (filters.category) {
    paramCount++;
    conditions.push(`personal_finance_category = $${paramCount}`);
    params.push(filters.category);
  }
  
  if (filters.startDate) {
    paramCount++;
    conditions.push(`date >= $${paramCount}`);
    params.push(filters.startDate);
  }
  
  if (filters.endDate) {
    paramCount++;
    conditions.push(`date <= $${paramCount}`);
    params.push(filters.endDate);
  }
  
  if (filters.search) {
    paramCount++;
    const searchParam = `%${filters.search}%`;
    conditions.push(`(name ILIKE $${paramCount} OR merchant_name ILIKE $${paramCount})`);
    params.push(searchParam);
  }
  
  // Add cursor condition if present
  if (cursorDate && cursorId) {
    conditions.push(`(date < $${paramCount+1} OR (date = $${paramCount+1} AND id < $${paramCount+2}))`);
    params.push(cursorDate, cursorId);
    paramCount += 2;
  }
  
  // Add limit parameter
  paramCount++;
  
  // Build the complete query
  const query = {
    text: `
      SELECT * FROM transactions 
      WHERE ${conditions.join(' AND ')} 
      ORDER BY date DESC, id DESC 
      LIMIT $${paramCount}
    `,
    values: [...params, limit],
  };
  
  const { rows: transactions } = await db.query(query);
  
  // Generate next cursor
  let nextCursor = null;
  if (transactions.length > 0) {
    const lastTx = transactions[transactions.length - 1];
    nextCursor = `${lastTx.date}:${lastTx.id}`;
  }
  
  // Get total count for this filter set (for pagination metadata)
  const countConditions = conditions.filter(c => !c.includes('(date <'));
  const countParams = params.filter((_, i) => i < (cursorDate && cursorId ? paramCount - 3 : paramCount - 1));
  
  const countQuery = {
    text: `SELECT COUNT(*) FROM transactions WHERE ${countConditions.join(' AND ')}`,
    values: countParams,
  };
  
  const { rows: countResult } = await db.query(countQuery);
  const totalCount = parseInt(countResult[0].count, 10);
  
  // For backward compatibility, return just the transactions array if no filtering is applied
  if (!cursor && !Object.keys(filters).length) {
    return transactions;
  }
  
  // Return enhanced result with pagination metadata
  return {
    transactions,
    pagination: {
      totalCount,
      limit,
      hasMore: transactions.length === limit,
      nextCursor
    }
  };
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
