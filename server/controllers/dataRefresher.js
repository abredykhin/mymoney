/**
 * @file Service for managing data refresh operations.
 */
const Bull = require('bull');
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
    logger.info('RefreshService instance created.');
  }

  async initialize() {
    await this._cleanQueueOnStartup();
    this._setupQueue();
    logger.info('RefreshService fully initialized and queue processor attached.');
    return this;
  }

  /**
   * Sets up the Bull queue and event handlers.
   */
  _setupQueue() {
    // Process jobs
    refreshQueue.process(async job => {
      const { userId, jobType } = job.data;

      logger.info(`Processing data refresh job for user ${userId}`);

      try {
        // Update job status to processing
        await refreshQueries.updateJobStatus(userId, job.id, 'processing');

        logger.info(`Starting ${jobType} refresh for user ${userId}`);

        // Perform the actual data refresh
        await this._performDataRefresh(userId);

        // Update job status to completed
        logger.info(`Data refresh completed for user ${userId}`);
        await refreshQueries.updateJobStatus(userId, job.id, 'completed');

        logger.info(`Completed ${jobType} refresh for user ${userId}`);

        return { success: true, userId, timestamp: new Date() };
      } catch (error) {
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
        logger.info(
          `Scheduling next refresh for user ${userId} after ${jobType} job completed`
        );
        // Introduce a small delay before scheduling the next one
        setTimeout(() => {
            this._scheduleNextRefresh(userId).catch(err => {
              logger.error(`Failed to schedule next refresh for user ${userId}: ${err.message}`);
            });
        }, 100);
      }
    });

    refreshQueue.on('failed', (job, error) => {
      logger.error(`Job ${job.id} failed: ${error.message}`);
    });
  }

  async _cleanQueueOnStartup() {
    try {
      logger.info('Cleaning data refresh queue state on startup...');
      const queue = refreshQueue; // Get the queue instance
      await queue.clean(0, 'active');
      await queue.clean(0, 'wait');
      await queue.clean(0, 'delayed');
      await queue.clean(0, 'completed'); 
      await queue.clean(0, 'failed');
      logger.info('Queue data refresh state cleaned.');
    } catch (error) {
      logger.error('Error cleaning data refresh queue on startup:', error);
    }
  }

  /**
   * Initializes scheduled refreshes for all users.
   *
   * @param {number} intervalHours The interval in hours (default: 12).
   * @returns {Promise<void>}
   */
  async initializeScheduledRefreshes(intervalHours = 12) {
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
        logger.info(
          `Initialized scheduled refresh for user ${userId} at ${adjustedInterval}`
        );
      }

      logger.info(
        `Scheduled refreshes initialized for ${userIds.length} users`
      );
    } catch (err) {
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
    logger.info(`Performing data refresh for user ${userId}`);

    const plaidItems = await retrieveItemsByUser(userId);

    // Invoke sync transactions for each plaid itemId
    for (const plaidItem of plaidItems) {
      const itemId = plaidItem.plaid_item_id;
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
      logger.info(`Canceling any pending jobs for user ${userId}`);
      await refreshQueue.clean(0, 'delayed', `userId:${userId}`); // Keep this line
    } catch (error) {
      // Log the error, but don't let it halt the process
      logger.info(
        `Error cleaning delayed jobs (likely empty data): ${error.message}`,
        'error'
      );
    }

    // Create a new job record
    logger.info(`Creating a new job record for user ${userId}`);
    const newJob = await refreshQueries.createRefreshJob(userId, 'manual');

    // Add to Bull queue
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

      logger.info(`Manual refresh queued for user ${userId}`);
      return {
        success: true,
        jobId: job.id,
        message: 'Refresh has been queued',
      };
    } catch (err) {
      logger.info(`Failed to queue manual refresh: ${err.message}`, 'error');
      throw err;
    }
  }

  /**
   * Performs manual refresh for all users in the system.
   * @returns {Promise<Object>} Result of the operation with job IDs
   */
  async requestManualRefreshAllUsers() {
    logger.info('Requesting manual refresh for all users');

    try {
      // Get all user IDs
      const userIds = await refreshQueries.getAllUserIds();

      if (userIds.length === 0) {
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
      logger.info(
        `Failed to request manual refresh for all users: ${err.message}`,
        'error'
      );
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

    await refreshQueries.updateNextScheduledTime(userId, nextRunTime);

    // Schedule the job
    const job = await refreshQueue.add(
      { userId, jobType: 'scheduled' },
      {
        jobId: `scheduled-${userId}-${Date.now()}`,
        delay: intervalHours * 60 * 60 * 1000, // Convert hours to milliseconds
      }
    );

    logger.info(`Next scheduled refresh for user ${userId} at ${nextRunTime}`);
    return job;
  }
}

// Export an async factory function INSTEAD of the instance
async function createAndInitializeRefreshService() {
  const service = new RefreshService();
  await service.initialize();
  return service;
}

module.exports = { createAndInitializeRefreshService }; 