/**
 * @file Service for managing data refresh operations.
 */
const Bull = require('bull');
const debug = require('debug')('services:refresh');
const logger = require('../utils/logger');
const refreshQueries = require('../db/queries/dataRefresh');
const { retrieveItemsByUser } = require('../db/queries/items');
const syncTransactions = require('../controllers/transactions');

// Create Bull queue with Redis
const refreshQueue = new Bull('data-refresh', {
  redis: {
    port: process.env.REDIS_PORT || 6379,
    host: process.env.REDIS_HOST || 'localhost',
    password: process.env.REDIS_PASSWORD,
    // Only use TLS if explicitly configured with env var
    tls: process.env.REDIS_USE_TLS === 'true',
    enableTLSForSentinelMode: false,
  },
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 5000,
    },
    removeOnComplete: false,
  },
});

/**
 * Service handling data refresh operations using Bull queue.
 */
class RefreshService {
  constructor() {
    //this.setupQueue();
  }

  /**
   * Sets up the Bull queue and event handlers.
   */
  setupQueue() {
    // Process jobs
    refreshQueue.process(async job => {
      const { userId, jobType } = job.data;

      debug(`Processing data refresh job for user ${userId}`);
      logger.info(`Processing data refresh job for user ${userId}`);

      try {
        // Update job status to processing
        await refreshQueries.updateJobStatus(userId, job.id, 'processing');

        debug(`Starting ${jobType} refresh for user ${userId}`);
        logger.info(`Starting ${jobType} refresh for user ${userId}`);

        // Perform the actual data refresh
        await this._performDataRefresh(userId);

        // Update job status to completed
        debug(`Data refresh completed for user ${userId}`);
        logger.info(`Data refresh completed for user ${userId}`);
        await refreshQueries.updateJobStatus(userId, job.id, 'completed');

        debug(`Completed ${jobType} refresh for user ${userId}`);
        logger.info(`Completed ${jobType} refresh for user ${userId}`);

        return { success: true, userId, timestamp: new Date() };
      } catch (error) {
        debug(`Refresh failed for user ${userId}: ${error.message}`);
        logger.error(`Refresh failed for user ${userId}: ${error.message}`);
        // Update job status to failed
        await refreshQueries.updateJobStatus(
          userId,
          job.id,
          'failed',
          error.message
        );
        throw error;
      }
    });

    // Set up event listeners
    refreshQueue.on('completed', job => {
      const { userId, jobType } = job.data;
      if (jobType === 'scheduled') {
        // Schedule the next refresh if this was a scheduled refresh
        debug(
          `Scheduling next refresh for user ${userId} after ${jobType} job completed`
        );
        logger.info(
          `Scheduling next refresh for user ${userId} after ${jobType} job completed`
        );
        this._scheduleNextRefresh(userId);
      }
    });

    refreshQueue.on('failed', (job, error) => {
      debug(`Refresh failed for user ${userId}: ${error.message}`);
      logger.error(`Job ${job.id} failed: ${error.message}`);
    });
  }

  /**
   * Initializes scheduled refreshes for all users.
   *
   * @param {number} intervalHours The interval in hours (default: 12).
   * @returns {Promise<void>}
   */
  async initializeScheduledRefreshes(intervalHours = 12) {
    debug(
      `Initializing scheduled refreshes with interval of ${intervalHours} hours`
    );
    logger.info(
      `Initializing scheduled refreshes with interval of ${intervalHours} hours`
    );

    try {
      const userIds = await refreshQueries.getAllUserIds();

      for (const userId of userIds) {
        // Schedule with random offset to avoid all users refreshing at same time
        const randomOffset = Math.floor(Math.random() * 60); // Random minutes
        const adjustedInterval = intervalHours + randomOffset / 60;

        await this._scheduleNextRefresh(userId, adjustedInterval);
        debug(
          `Initialized scheduled refresh for user ${userId} at ${adjustedInterval}`
        );
        logger.info(
          `Initialized scheduled refresh for user ${userId} at ${adjustedInterval}`
        );
      }

      debug(`Scheduled refreshes initialized for ${userIds.length} users`);
      logger.info(
        `Scheduled refreshes initialized for ${userIds.length} users`
      );
    } catch (err) {
      debug(`Failed to initialize scheduled refreshes: ${err.message}`);
      logger.error(`Failed to initialize scheduled refreshes: ${err.message}`);
      throw err;
    }
  }

  /**
   * Gets the refresh status for a user.
   *
   * @param {number} userId The ID of the user.
   * @returns {Promise<Object>} The refresh status.
   */
  async getRefreshStatus(userId) {
    try {
      const status = await refreshQueries.getRefreshStatus(userId);

      if (!status) {
        return {
          status: 'never_run',
          lastRefreshTime: null,
          nextScheduledTime: null,
        };
      }

      return {
        status: status.status,
        jobType: status.job_type,
        lastRefreshTime: status.last_refresh_time,
        nextScheduledTime: status.next_scheduled_time,
        errorMessage: status.error_message,
      };
    } catch (err) {
      debug(`Failed to get refresh status: ${err.message}`);
      logger.error(`Failed to get refresh status: ${err.message}`);
      throw err;
    }
  }

  /**
   * Performs the actual data refresh operation.
   *
   * @param {number} userId The ID of the user.
   * @returns {Promise<void>}
   */
  async _performDataRefresh(userId) {
    debug(`Starting data refresh for user ${userId}`);
    logger.info(`Performing data refresh for user ${userId}`);

    const plaidItems = await retrieveItemsByUser(userId);

    // Invoke sync transactions for each plaid itemId
    for (const plaidItem of plaidItems) {
      const itemId = plaidItem.plaid_item_id;
      debug(`Syncing transactions for item ${itemId}`);
      logger.info(`Syncing transactions for item ${itemId}`);
      await syncTransactions(itemId);
    }
  }

  /**
   * Checks if a user has an active refresh in progress.
   * @param {number} userId
   * @returns {Promise<boolean>} True if a job is already processing
   */
  async _isRefreshInProgress(userId) {
    const processingJob = await refreshQueries.getProcessingJob(userId);
    if (processingJob) {
      debug(
        `Manual refresh requested but a job is already processing for user ${userId}`
      );
      logger.info(
        `Manual refresh requested but a job is already processing for user ${userId}`
      );
      return true;
    }
    return false;
  }

  /**
   * Creates and schedules a new refresh job
   * @param {number} userId
   * @returns {Promise<Object>} Created job info
   */
  async _createAndScheduleJob(userId) {
    // Cancel any pending jobs for this user
    try {
      // Cancel any pending jobs for this user
      debug(`Canceling any pending jobs for user ${userId}`);
      logger.info(`Canceling any pending jobs for user ${userId}`);
      await refreshQueue.clean(0, 'delayed', `userId:${userId}`); // Keep this line
    } catch (error) {
      // Log the error, but don't let it halt the process
      debug(
        `Error cleaning delayed jobs (likely empty data): ${error.message}`,
        'error'
      );
      logger.info(
        `Error cleaning delayed jobs (likely empty data): ${error.message}`,
        'error'
      );
    }

    // Create a new job record
    debug(`Creating a new job record for user ${userId}`);
    logger.info(`Creating a new job record for user ${userId}`);
    const newJob = await refreshQueries.createRefreshJob(userId, 'manual');

    // Add to Bull queue
    debug(`Adding job to Bull queue for user ${userId}`);
    logger.info(`Adding job to Bull queue for user ${userId}`);
    const job = await refreshQueue.add(
      { userId, jobType: 'manual', jobDbId: newJob.id },
      { jobId: `manual-${userId}-${Date.now()}` }
    );

    // Update the job record with the Bull job ID
    await refreshQueries.updateJobId(newJob.id, job.id);

    return job;
  }

  /**
   * Requests a manual refresh for a user.
   * @param {number} userId The ID of the user.
   * @returns {Promise<Object>} Result of the operation.
   */
  async requestManualRefresh(userId) {
    debug(`Requesting manual refresh for user ${userId}`);
    logger.info(`Requesting manual refresh for user ${userId}`);

    try {
      // Check if a refresh is already in progress
      if (await this._isRefreshInProgress(userId)) {
        return {
          success: false,
          message: 'A data refresh is already in progress',
        };
      }

      // Create and schedule the job
      const job = await this._createAndScheduleJob(userId);

      debug(`Manual refresh queued for user ${userId}`);
      logger.info(`Manual refresh queued for user ${userId}`);
      return {
        success: true,
        jobId: job.id,
        message: 'Refresh has been queued',
      };
    } catch (err) {
      debug(`Failed to queue manual refresh: ${err.message}`, 'error');
      logger.info(`Failed to queue manual refresh: ${err.message}`, 'error');
      throw err;
    }
  }

  /**
   * Performs manual refresh for all users in the system.
   * @returns {Promise<Object>} Result of the operation with job IDs
   */
  async requestManualRefreshAllUsers() {
    debug('Requesting manual refresh for all users');
    logger.info('Requesting manual refresh for all users');

    try {
      // Get all user IDs
      const userIds = await refreshQueries.getAllUserIds();

      if (userIds.length === 0) {
        debug('No users found for refresh');
        return {
          success: false,
          message: 'No users found for refresh',
        };
      }

      // Queue refresh jobs for all users
      const jobResults = [];
      for (const userId of userIds) {
        try {
          // Use the existing requestManualRefresh method for each user
          const result = await this.requestManualRefresh(userId);
          jobResults.push({ userId, ...result });
        } catch (err) {
          debug(
            `Failed to queue refresh for user ${userId}: ${err.message}`,
            'error'
          );
          logger.info(
            `Failed to queue refresh for user ${userId}: ${err.message}`,
            'error'
          );
          jobResults.push({
            userId,
            success: false,
            message: `Failed to queue: ${err.message}`,
          });
        }
      }

      // Count successful jobs
      const successCount = jobResults.filter(job => job.success).length;

      debug(
        `Manual refresh queued for ${successCount} out of ${userIds.length} users`
      );
      logger.info(
        `Manual refresh queued for ${successCount} out of ${userIds.length} users`
      );

      return {
        success: successCount > 0,
        totalUsers: userIds.length,
        successfulJobs: successCount,
        jobResults,
        message: `Refresh has been queued for ${successCount} out of ${userIds.length} users`,
      };
    } catch (err) {
      debug(
        `Failed to request manual refresh for all users: ${err.message}`,
        'error'
      );
      logger.info(
        `Failed to request manual refresh for all users: ${err.message}`,
        'error'
      );
      throw err;
    }
  }

  /**
   * Triggers an immediate data refresh for all users.
   * Processes users in batches to prevent system overload.
   *
   * @param {number} batchSize Number of users to process in each batch (default: 5)
   * @returns {Promise<void>}
   */
  async refreshAllUsers(batchSize = 5) {
    try {
      debug('Triggering immediate data refresh for all users');
      logger.info('Triggering immediate data refresh for all users');
      const userIds = await refreshQueries.getAllUserIds();

      if (userIds.length === 0) {
        debug('No users found for refresh');
        logger.info('No users found for refresh');
        return;
      }

      // Process in batches to avoid overwhelming the system
      for (let i = 0; i < userIds.length; i += batchSize) {
        const batch = userIds.slice(i, i + batchSize);
        debug(
          `Processing refresh batch ${Math.floor(i / batchSize) + 1} of ${Math.ceil(userIds.length / batchSize)}`
        );
        logger.info(
          `Processing refresh batch ${Math.floor(i / batchSize) + 1} of ${Math.ceil(userIds.length / batchSize)}`
        );

        // Queue refresh jobs in parallel for this batch
        await Promise.all(
          batch.map(userId =>
            this.requestManualRefresh(userId)
              .then(result => {
                if (result.success) {
                  debug(`Queued refresh for user ${userId}`);
                  logger.info(`Queued refresh for user ${userId}`);
                } else {
                  debug(
                    `Skipped refresh for user ${userId}: ${result.message}`
                  );
                  logger.info(
                    `Skipped refresh for user ${userId}: ${result.message}`
                  );
                }
              })
              .catch(err => {
                debug(
                  `Failed to queue refresh for user ${userId}: ${err.message}`
                );
                logger.error(
                  `Failed to queue refresh for user ${userId}: ${err.message}`
                );
              })
          )
        );

        // Small delay between batches to avoid Redis/DB connection spikes
        if (i + batchSize < userIds.length) {
          await new Promise(resolve => setTimeout(resolve, 1000));
        }
      }

      debug(`Immediate refresh queued for ${userIds.length} users`);
      logger.info(`Immediate refresh queued for ${userIds.length} users`);
    } catch (err) {
      debug(`Error refreshing all users: ${err.message}`);
      logger.error(`Error refreshing all users: ${err.message}`);
      throw err;
    }
  }

  /**
   * Schedules the next refresh for a user.
   *
   * @param {number} userId The ID of the user.
   * @param {number} intervalHours The interval in hours (default: 12).
   * @returns {Promise<Object>} The scheduled job.
   */
  async _scheduleNextRefresh(userId, intervalHours = 12) {
    // Calculate next run time
    const nextRunTime = new Date();
    nextRunTime.setHours(nextRunTime.getHours() + intervalHours);

    debug(`Scheduling next refresh for user ${userId} at ${nextRunTime}`);
    logger.info(`Scheduling next refresh for user ${userId} at ${nextRunTime}`);
    // Update the next scheduled time in the database
    await refreshQueries.updateNextScheduledTime(userId, nextRunTime);

    debug(`Next scheduled refresh for user ${userId} at ${nextRunTime}`);
    logger.info(`Next scheduled refresh for user ${userId} at ${nextRunTime}`);
    // Schedule the job
    const job = await refreshQueue.add(
      { userId, jobType: 'scheduled' },
      {
        jobId: `scheduled-${userId}-${Date.now()}`,
        delay: intervalHours * 60 * 60 * 1000, // Convert hours to milliseconds
      }
    );

    debug(`Next scheduled refresh for user ${userId} at ${nextRunTime}`);
    logger.info(`Next scheduled refresh for user ${userId} at ${nextRunTime}`);
    return job;
  }
}

// Create singleton instance
const refreshService = new RefreshService();

module.exports = refreshService;
