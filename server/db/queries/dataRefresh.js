/**
 * @file Defines the queries for the refresh_jobs table.
 */
const db = require('../');
const debug = require('debug')('queries:refresh');
require('util').inspect.defaultOptions.depth = null;

/**
 * Creates a refresh job record.
 *
 * @param {number} userId The ID of the user.
 * @param {string} jobType The type of job ('manual' or 'scheduled').
 * @returns {Object} The created refresh job.
 */
const createRefreshJob = async (userId, jobType) => {
  const query = {
    text: `INSERT INTO refresh_jobs 
           (user_id, status, job_type, created_at, updated_at) 
           VALUES ($1, 'pending', $2, NOW(), NOW())
           RETURNING *;`,
    values: [userId, jobType],
  };
  const res = await db.query(query);
  return res.rows[0];
};

/**
 * Updates a refresh job with the Bull queue job ID.
 *
 * @param {number} jobDbId The ID of the job in the database.
 * @param {string} bullJobId The ID of the job in the Bull queue.
 * @returns {Object} The updated refresh job.
 */
const updateJobId = async (jobDbId, bullJobId) => {
  const query = {
    text: 'UPDATE refresh_jobs SET job_id = $1 WHERE id = $2 RETURNING *;',
    values: [bullJobId, jobDbId],
  };
  const res = await db.query(query);
  return res.rows[0];
};

/**
 * Updates the status of a refresh job.
 *
 * @param {number} userId The ID of the user.
 * @param {string} jobId The ID of the job in the Bull queue.
 * @param {string} status The new status ('pending', 'processing', 'completed', 'failed').
 * @param {string|null} errorMessage The error message if status is 'failed'.
 * @returns {Object} The updated refresh job.
 */
const updateJobStatus = async (userId, jobId, status, errorMessage = null) => {
  const query = {
    text: `
      UPDATE refresh_jobs 
      SET status = $1, 
          updated_at = NOW(), 
          ${status === 'completed' ? 'last_refresh_time = NOW(),' : ''} 
          error_message = $4
      WHERE user_id = $2 AND job_id = $3
      RETURNING *;
    `,
    values: [status, userId, jobId, errorMessage],
  };
  const res = await db.query(query);
  return res.rows[0];
};

/**
 * Gets any processing jobs for a user.
 *
 * @param {number} userId The ID of the user.
 * @returns {Object|null} The processing job if exists, null otherwise.
 */
const getProcessingJob = async userId => {
  const query = {
    text: `
      SELECT * FROM refresh_jobs 
      WHERE user_id = $1 AND status = 'processing'
      LIMIT 1;
    `,
    values: [userId],
  };
  const res = await db.query(query);
  return res.rows.length ? res.rows[0] : null;
};

/**
 * Updates the next scheduled refresh time for a user.
 *
 * @param {number} userId The ID of the user.
 * @param {Date} nextScheduledTime The next scheduled refresh time.
 * @returns {Object} The updated refresh job.
 */
const updateNextScheduledTime = async (userId, nextScheduledTime) => {
  const query = {
    text: `
      UPDATE refresh_jobs 
      SET next_scheduled_time = $2 
      WHERE user_id = $1 AND status = 'completed'
      ORDER BY updated_at DESC
      LIMIT 1
      RETURNING *;
    `,
    values: [userId, nextScheduledTime],
  };
  const res = await db.query(query);
  return res.rows[0];
};

/**
 * Gets the latest refresh status for a user.
 *
 * @param {number} userId The ID of the user.
 * @returns {Object|null} The latest refresh job, null if no jobs exist.
 */
const getRefreshStatus = async userId => {
  const query = {
    text: `
      SELECT * FROM refresh_jobs
      WHERE user_id = $1
      ORDER BY 
        CASE status 
          WHEN 'processing' THEN 1
          WHEN 'pending' THEN 2 
          WHEN 'completed' THEN 3
          WHEN 'failed' THEN 4
        END,
        updated_at DESC
      LIMIT 1;
    `,
    values: [userId],
  };
  const res = await db.query(query);
  return res.rows.length ? res.rows[0] : null;
};

/**
 * Gets all user IDs from the users table.
 *
 * @returns {Array} Array of user IDs.
 */
const getAllUserIds = async () => {
  const query = {
    text: 'SELECT id FROM users_table;',
  };
  const res = await db.query(query);
  return res.rows.map(row => row.id);
};

module.exports = {
  createRefreshJob,
  updateJobId,
  updateJobStatus,
  getProcessingJob,
  updateNextScheduledTime,
  getRefreshStatus,
  getAllUserIds,
};
