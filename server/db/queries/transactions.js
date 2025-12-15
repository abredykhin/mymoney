/**
 * @file Defines the queries for the transactions table.
 */

const { retrieveAccountByPlaidAccountId } = require('./accounts');
const db = require('../');
const debug = require('debug')('db:transactions');
const logger = require('../../utils/logger');

/**
 * Creates or updates multiple transactions.
 * OPTIMIZED: Uses batch operations instead of individual queries.
 *
 * @param {Object[]} transactions an array of transactions.
 */
const createOrUpdateTransactions = async transactions => {
  debug(`Storing ${transactions.length} transactions in db using batch insert...`);

  if (!transactions || transactions.length === 0) {
    debug('No transactions to store');
    return { success: true };
  }

  const client = await db.connect(); // Obtain a single client (connection)
  try {
    await client.query('BEGIN'); // Start transaction

    // OPTIMIZATION 1: Batch fetch all account IDs in a single query
    const uniquePlaidAccountIds = [...new Set(transactions.map(t => t.account_id))];
    const accountQuery = {
      text: `
        SELECT id, plaid_account_id
        FROM accounts
        WHERE plaid_account_id = ANY($1::text[])
      `,
      values: [uniquePlaidAccountIds],
    };
    const { rows: accounts } = await client.query(accountQuery);

    // Create a map for O(1) lookup: plaid_account_id -> internal account id
    const accountIdMap = new Map(
      accounts.map(acc => [acc.plaid_account_id, acc.id])
    );
    debug(`Fetched ${accounts.length} account mappings in single query`);

    // OPTIMIZATION 2: Build batch INSERT statement
    const values = [];
    const valuePlaceholders = [];
    let paramIndex = 1;

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

      // Get account ID from our map
      const accountId = accountIdMap.get(transaction.account_id);
      if (!accountId) {
        debug(`Warning: Account not found for plaid_account_id: ${transaction.account_id}, skipping transaction ${transaction_id}`);
        continue; // Skip this transaction
      }

      const {
        primary: personal_finance_category = null,
        detailed: personal_finance_subcategory = null,
      } = transaction.personal_finance_category || {};

      // Add values for this transaction (15 parameters)
      values.push(
        accountId,
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
        pending_transaction_transaction_id || null
      );

      // Create placeholder string for this row: ($1, $2, ..., $15)
      const rowPlaceholders = [];
      for (let i = 0; i < 15; i++) {
        rowPlaceholders.push(`$${paramIndex++}`);
      }
      valuePlaceholders.push(`(${rowPlaceholders.join(', ')})`);
    }

    if (valuePlaceholders.length === 0) {
      debug('No valid transactions to insert after account mapping');
      await client.query('COMMIT');
      return { success: true };
    }

    // Build and execute single batch INSERT query
    const batchInsertQuery = {
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
          ${valuePlaceholders.join(',\n          ')}
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
            pending_transaction_transaction_id = EXCLUDED.pending_transaction_transaction_id
      `,
      values: values,
    };

    debug(`Executing batch insert with ${valuePlaceholders.length} transactions in single query`);
    await client.query(batchInsertQuery);

    await client.query('COMMIT'); // Commit transaction after batch insert succeeds
    debug(`Successfully stored ${valuePlaceholders.length} transactions using batch insert`);
    return { success: true };
  } catch (err) {
    await client.query('ROLLBACK'); // Rollback transaction in case of error
    debug('Error storing transactions, transaction rolled back:', err);
    logger.error('Batch insert failed:', err);
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
 * OPTIMIZED: Uses batch delete instead of individual queries.
 *
 * @param {string[]} plaidTransactionIds the Plaid IDs of the transactions.
 */
const deleteTransactions = async plaidTransactionIds => {
  if (!plaidTransactionIds || plaidTransactionIds.length === 0) {
    debug('No transactions to delete');
    return;
  }

  // OPTIMIZATION: Single batch DELETE using ANY clause
  const query = {
    text: 'DELETE FROM transactions_table WHERE transaction_id = ANY($1::text[])',
    values: [plaidTransactionIds],
  };

  debug(`Deleting ${plaidTransactionIds.length} transactions in single query`);
  await db.query(query);
  debug(`Successfully deleted ${plaidTransactionIds.length} transactions`);
};

/**
 * Retrieves spending breakdown by primary category for the current week (to date), month, and year.
 * Dates are calculated based on the database's CURRENT_DATE.
 *
 * @param {'user_id' | 'account_id'} idFieldName - The column to filter by ('user_id' or 'account_id').
 * @param {number | string} idValue - The ID of the user or account.
 * @param {string} currentDateString - The current date from the client in 'YYYY-MM-DD' format.
 * @param {'sunday' | 'monday'} weekStartDay - Specifies if the week starts on Sunday or Monday. Defaults to 'monday'.
 * @returns {Promise<Array<{category: string, weekly_spend: number, monthly_spend: number, yearly_spend: number}>>}
 */
const getSpendBreakdownByCategory = async (idFieldName, idValue, currentDateString, weekStartDay = 'monday') => {
    // --- 1. Validate Inputs ---
    if (idFieldName !== 'user_id' && idFieldName !== 'account_id') {
        throw new Error('Invalid idFieldName specified. Must be "user_id" or "account_id".');
    }
    if (weekStartDay !== 'sunday' && weekStartDay !== 'monday') {
        debug(`Invalid weekStartDay value "${weekStartDay}", defaulting to "monday".`);
        weekStartDay = 'monday'; // Default to Monday if invalid value provided
    }
    // Basic validation for date string format (can be enhanced)
    if (!/^\d{4}-\d{2}-\d{2}$/.test(currentDateString)) {
        throw new Error('Invalid currentDateString format. Expected "YYYY-MM-DD".');
    }
    const clientDate = currentDateString; // Use the validated string directly for SQL parameter

    // --- 2. Construct SQL Query ---
    // Parameters: $1 = weekStartDay, $2 = idValue, $3 = clientDate (currentDateString)
    const sql = `
    WITH UserInput AS (
        SELECT
            $3::date AS today,      -- $3 = clientDate (currentDateString)
            $1 AS week_start_pref   -- $1 = weekStartDay
    ),
    CalculatedActualWeekStart AS (
        -- This CTE determines the actual start of the week *containing* 'today'
        -- based on the week_start_pref.
        SELECT
            today,
            week_start_pref,
            CASE
                WHEN week_start_pref = 'sunday' THEN
                    -- For Sunday start, date_trunc to week after adding 1 day, then subtract 1 day
                    date_trunc('week', today + interval '1 day')::date - interval '1 day'
                ELSE
                    -- For Monday start, date_trunc directly works.
                    date_trunc('week', today)::date
            END AS current_actual_week_start
        FROM UserInput
    ),
    DateRanges AS (
        -- This CTE adjusts the week_start_date if 'today' is the first day of its actual week.
        -- All end dates are 'today + 1 day' (exclusive) for correct range filtering.
        SELECT
            caws.today,
            CASE
                -- If 'today' IS the first day of its calculated week,
                -- then the reporting week_start_date should be 7 days prior.
                WHEN caws.current_actual_week_start = caws.today THEN
                    caws.current_actual_week_start - interval '7 days'
                -- Otherwise, use the calculated actual start of the week.
                ELSE
                    caws.current_actual_week_start
            END AS week_start_date,
            caws.today + interval '1 day' AS week_end_date, -- End of 'today' (exclusive)

            date_trunc('month', caws.today)::date AS month_start_date,
            caws.today + interval '1 day' AS month_end_date, -- End of 'today' (exclusive)

            date_trunc('year', caws.today)::date AS year_start_date,
            caws.today + interval '1 day' AS year_end_date -- End of 'today' (exclusive)
        FROM CalculatedActualWeekStart caws
    )
    SELECT
        COALESCE(t.personal_finance_category, 'Uncategorized') AS category,
        -- Sum amounts within the calculated week range
        SUM(CASE WHEN t.date >= dr.week_start_date AND t.date < dr.week_end_date THEN t.amount ELSE 0 END)::numeric(28, 2) AS weekly_spend,
        -- Sum amounts within the calculated month range
        SUM(CASE WHEN t.date >= dr.month_start_date AND t.date < dr.month_end_date THEN t.amount ELSE 0 END)::numeric(28, 2) AS monthly_spend,
        -- Sum amounts within the calculated year range
        SUM(CASE WHEN t.date >= dr.year_start_date AND t.date < dr.year_end_date THEN t.amount ELSE 0 END)::numeric(28, 2) AS yearly_spend
    FROM
        transactions t
    CROSS JOIN DateRanges dr -- Use CROSS JOIN as DateRanges produces a single row
    WHERE
        t.${idFieldName} = $2 -- Use $2 for idValue
        AND t.pending = false
        -- Filter transactions to be within the relevant year for efficiency (year_start_date to today)
        AND t.date >= dr.year_start_date 
        AND t.date < dr.year_end_date   
        AND t.amount > 0
    GROUP BY
        COALESCE(t.personal_finance_category, 'Uncategorized')
    ORDER BY
        yearly_spend DESC, monthly_spend DESC, weekly_spend DESC;
    `;

    // Pass weekStartDay, idValue, and clientDate as parameters
    const params = [weekStartDay, idValue, clientDate];

    try {
        const { rows } = await db.query(sql, params);
        debug(`Retrieved ${rows.length} category breakdowns for ${idFieldName}=${idValue} on ${clientDate}.`);
        // Convert numeric string amounts to numbers
        return rows.map(row => ({
            category: row.category,
            weekly_spend: Number(row.weekly_spend) || 0,
            monthly_spend: Number(row.monthly_spend) || 0,
            yearly_spend: Number(row.yearly_spend) || 0,
        }));
    } catch (error) {
        logger.error(`Error fetching spend breakdown for ${idFieldName}=${idValue} on ${clientDate}:`, error);
        if (error.message) {
            debug(`SQL Error: ${error.message}`);
        }
        throw error; // Re-throw the error for higher-level handling
    }
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
  getSpendBreakdownByCategory,
};
