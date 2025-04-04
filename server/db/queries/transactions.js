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

const retrieveTransactionsByAccountId = async (accountId, options = {}) => {
  debug(`Retrieving transactions for account ${accountId}`);
  return _retrieveTransactions('account_id', accountId, options);
};

const retrieveTransactionsByUserId = async (userId, options = {}) => {
  debug(`Retrieving transactions for user ${userId}`);
  return _retrieveTransactions('user_id', userId, options);
};

const retrieveTransactionsByItemId = async (itemId, options = {}) => {
  debug(`Retrieving transactions for item ${itemId}`);
  return _retrieveTransactions('item_id', itemId, options);
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

/**
 * Internal helper function to retrieve transactions based on a dynamic ID field.
 * Handles filtering, pagination (cursor), sorting, and counting.
 * (Assumes 'date' column in DB is of type DATE)
 * ... (rest of JSDoc) ...
 */
const _retrieveTransactions = async (idFieldName, idValue, options = {}) => {
  const { limit = 50, cursor = null, filters = {} } = options;

  let cursorDate = null; // YYYY-MM-DD formatted string
  let cursorId = null;   // Parsed integer ID

  // --- 1. Parse Cursor ---
  if (cursor) {
    try {
      const lastColonIndex = cursor.lastIndexOf(':');
      if (lastColonIndex <= 0 || lastColonIndex === cursor.length - 1) {
        throw new Error('Cursor does not appear to contain a date and ID separated by a colon.');
      }
      const dateStr = cursor.substring(0, lastColonIndex);
      const idStr = cursor.substring(lastColonIndex + 1);

      // Even if dateStr includes time, new Date() parses it.
      const parsedDate = new Date(dateStr);
      if (isNaN(parsedDate.getTime())) {
        throw new Error(`Invalid time value obtained after parsing date string: ${dateStr}`);
      }

      // *** CHANGE HERE: Format back to YYYY-MM-DD for DATE column comparison ***
      cursorDate = parsedDate.toISOString().split('T')[0];

      cursorId = parseInt(idStr, 10);
      if (isNaN(cursorId)) {
        throw new Error(`Invalid number format obtained after parsing ID string: ${idStr}`);
      }
      debug(`Parsed cursor: date='${cursorDate}', id=${cursorId} from original='${cursor}'`);

    } catch (err) {
      debug(`Invalid cursor format or content: ${cursor}, error: ${err.message}. Proceeding without cursor.`);
      cursorDate = null;
      cursorId = null;
    }
  }

  // --- 2. Build Base Conditions & Parameters (without cursor) ---
  let conditions = [`${idFieldName} = $1`]; // Use dynamic field name
  let params = [idValue];                  // Use dynamic ID value
  let paramCount = 1;

  // Add filter conditions (Checks like date >= $N and date <= $N work fine with DATE type and YYYY-MM-DD strings)
  if (filters.category) {
    paramCount++;
    conditions.push(`personal_finance_category = $${paramCount}`);
    params.push(filters.category);
  }
  if (filters.startDate) {
    paramCount++;
    conditions.push(`date >= $${paramCount}`);
    params.push(filters.startDate); // Assuming startDate is also YYYY-MM-DD
  }
  if (filters.endDate) {
    paramCount++;
    conditions.push(`date <= $${paramCount}`);
    params.push(filters.endDate); // Assuming endDate is also YYYY-MM-DD
  }
   if (filters.search) {
    paramCount++;
    const searchParam = `%${filters.search}%`;
    conditions.push(`(name ILIKE $${paramCount} OR merchant_name ILIKE $${paramCount})`);
    params.push(searchParam);
  }

  // --- Store base conditions/params for the COUNT query ---
  const countConditions = [...conditions];
  const countParams = [...params];

  // --- 3. Add Cursor Condition (if applicable) ---
  if (cursorDate && cursorId) {
    // Comparison (date < $N OR (date = $N AND id < $N)) is correct for DATE type
    // using the YYYY-MM-DD formatted cursorDate string.
    conditions.push(`(date < $${paramCount + 1} OR (date = $${paramCount + 1} AND id < $${paramCount + 2}))`);
    params.push(cursorDate, cursorId);
    paramCount += 2;
  }

  // --- 4. Prepare and Execute Main Query ---
  paramCount++; // Increment for the LIMIT parameter placeholder
  const query = {
    text: `
      SELECT * FROM transactions
      WHERE ${conditions.join(' AND ')}
      ORDER BY date DESC, id DESC
      LIMIT $${paramCount}
    `,
    values: [...params, limit],
  };

  debug(`Executing query: ${query.text.replace(/\s+/g, ' ').trim()} with values: ${JSON.stringify(query.values)}`);
  const { rows: transactions } = await db.query(query);

  // --- 5. Generate Next Cursor ---
  // (This part remains unchanged - it correctly gets YYYY-MM-DD from lastTx.date)
  let nextCursor = null;
  if (transactions.length === limit) {
    const lastTx = transactions[transactions.length - 1];
     if (lastTx && lastTx.date && lastTx.id) {
        const lastTxDate = new Date(lastTx.date); // Convert DB date (likely Date obj or YYYY-MM-DD string) to Date obj
        if (!isNaN(lastTxDate.getTime())) {
             // Format consistently to YYYY-MM-DD for the cursor string
             const formattedDate = lastTxDate.toISOString().split('T')[0];
             nextCursor = `${formattedDate}:${lastTx.id}`;
             debug(`Generated nextCursor: ${nextCursor} from last tx id: ${lastTx.id}, date: ${formattedDate}`);
        } else {
            debug(`Warning: Invalid date found in last transaction (id: ${lastTx.id}), cannot generate nextCursor.`);
        }
    } else {
         debug(`Warning: Last transaction missing date or id, cannot generate nextCursor.`);
    }
  } else {
     debug(`Not generating nextCursor, retrieved transactions (${transactions.length}) less than limit (${limit})`);
  }


  // --- 6. Prepare and Execute Count Query ---
  // (Remains unchanged)
   const countQuery = {
    text: `SELECT COUNT(*) FROM transactions WHERE ${countConditions.join(' AND ')}`,
    values: countParams,
  };
  debug(`Executing count query: ${countQuery.text.replace(/\s+/g, ' ').trim()} with values: ${JSON.stringify(countQuery.values)}`);
  const { rows: countResult } = await db.query(countQuery);
  const totalCount = parseInt(countResult[0].count, 10);


  // --- 7. Format and Return Result ---
  // (Remains unchanged)
  const result = {
    transactions,
    pagination: {
      totalCount,
      limit,
      hasMore: nextCursor !== null,
      nextCursor,
    },
  };
  debug(`Returning ${transactions.length} transactions for ${idFieldName}=${idValue}. Total count: ${totalCount}. Has more: ${result.pagination.hasMore}.`);
  return result;
};


module.exports = {
  createOrUpdateTransactions,
  retrieveTransactionsByAccountId,
  retrieveTransactionsByItemId,
  retrieveTransactionsByUserId,
  deleteTransactions,
};
