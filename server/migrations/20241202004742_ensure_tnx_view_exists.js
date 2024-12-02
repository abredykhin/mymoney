/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function (knex) {
  return await knex.raw(`
        CREATE VIEW transactions
        AS
        SELECT
            t.id,
            t.account_id,
            a.user_id,
            a.plaid_account_id,
            a.item_id,
            a.plaid_item_id,
            t.amount,
            t.iso_currency_code,
            t.date,
            t.authorized_date,
            t.name,
            t.merchant_name,
            t.logo_url,
            t.website,
            t.payment_channel,
            t.transaction_id,
            t.personal_finance_category,
            t.personal_finance_subcategory,
            t.pending,
            t.pending_transaction_transaction_id,
            t.created_at,
            t.updated_at
        FROM
            transactions_table t
            LEFT JOIN accounts a ON t.account_id = a.id;
  `);
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function (knex) {};
