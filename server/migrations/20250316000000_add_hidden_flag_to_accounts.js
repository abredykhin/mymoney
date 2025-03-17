/**
 * Migration to add hidden flag to accounts
 */
exports.up = function (knex) {
  return knex.schema.table('accounts_table', function (table) {
    table.boolean('hidden').defaultTo(false);
  });
};

exports.down = function (knex) {
  return knex.schema.table('accounts_table', function (table) {
    table.dropColumn('hidden');
  });
};