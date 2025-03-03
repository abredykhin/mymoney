exports.up = function (knex) {
  return knex.schema.createTable('refresh_jobs', function (table) {
    table.increments('id').primary();
    table
      .integer('user_id')
      .notNullable()
      .references('id')
      .inTable('users_table')
      .onDelete('CASCADE');
    table
      .text('status')
      .notNullable()
      .checkIn(['pending', 'processing', 'completed', 'failed']);
    table.text('job_type').notNullable().checkIn(['manual', 'scheduled']);
    table.text('job_id').unique();
    table.timestamp('last_refresh_time', { useTz: true });
    table.timestamp('next_scheduled_time', { useTz: true });
    table.timestamp('created_at', { useTz: true }).defaultTo(knex.fn.now());
    table.timestamp('updated_at', { useTz: true }).defaultTo(knex.fn.now());
    table.text('error_message');

    table.index('user_id', 'refresh_jobs_user_id_idx');
    table.index('status', 'refresh_jobs_status_idx');
  });
};

exports.down = function (knex) {
  return knex.schema.dropTableIfExists('refresh_jobs');
};
