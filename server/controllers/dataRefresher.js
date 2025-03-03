/**
 * @file Service for managing data refresh operations.
 */
const Bull = require('bull');
const debug = require('debug')('services:refresh');
const logger = require('../utils/logger');
const refreshQueries = require('../queries/refresh');

// Create Bull queue with Redis
const refreshQueue = new Bull('data-refresh', {
  redis: {
    port: process.env.REDIS_PORT || 6379,
    host: process.env.REDIS_HOST || 'localhost',
    password: process.env.REDIS_PASSWORD,
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
    this.setupQueue();
  }

  /**
   * Sets up the Bull queue and event handlers.
   */
  setupQueue() {
    // Process jobs
    refreshQueue.process(async job => {
      const { userId, jobType } = job.data;

      try {
        // Update job status to processing
        await refreshQueries.updateJobStatus(userId, job.id, 'processing');

        debug(`Starting ${jobType} refresh for user ${userId}`);
        logger.info(`Starting ${jobType} refresh for user ${userId}`);

        // Perform the actual data refresh
        await this.performDataRefresh(userId);

        // Update job status to completed
        await refreshQueries.updateJobStatus(userId, job.id, 'completed');

        debug(`Completed ${jobType} refresh for user ${userId}`);
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
        this.scheduleNextRefresh(userId);
      }
    });

    refreshQueue.on('failed', (job, error) => {
      logger.error(`Job ${job.id} failed: ${error.message}`);
    });
  }

  /**
   * Performs the actual data refresh operation.
   *
   * @param {number} userId The ID of the user.
   * @returns {Promise<void>}
   */
  async performDataRefresh(userId) {
    // Implement your actual data refresh logic here
    // This would fetch new transactions from Plaid and update your database

    // For demonstration purposes, we'll just wait a bit
    await new Promise(resolve => setTimeout(resolve, 5000));
  }

  /**
   * Requests a manual refresh for a user.
   *
   * @param {number} userId The ID of the user.
   * @returns {Promise<Object>} Result of the operation.
   */
  async requestManualRefresh(userId) {
    try {
      // Check if a refresh is already in progress
      const processingJob = await refreshQueries.getProcessingJob(userId);

      if (processingJob) {
        logger.info(
          `Manual refresh requested but a job is already processing for user ${userId}`
        );
        return {
          success: false,
          message: 'A data refresh is already in progress',
        };
      }

      // Cancel any pending jobs for this user
      await refreshQueue.clean(0, 'delayed', `userId:${userId}`);

      // Create a new job record
      const newJob = await refreshQueries.createRefreshJob(userId, 'manual');

      // Add to Bull queue
      const job = await refreshQueue.add(
        { userId, jobType: 'manual', jobDbId: newJob.id },
        { jobId: `manual-${userId}-${Date.now()}` }
      );

      // Update the job record with the Bull job ID
      await refreshQueries.updateJobId(newJob.id, job.id);

      logger.info(`Manual refresh queued for user ${userId}`);
      return {
        success: true,
        jobId: job.id,
        message: 'Refresh has been queued',
      };
    } catch (err) {
      logger.error(`Failed to queue manual refresh: ${err.message}`);
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
  async scheduleNextRefresh(userId, intervalHours = 12) {
    // Calculate next run time
    const nextRunTime = new Date();
    nextRunTime.setHours(nextRunTime.getHours() + intervalHours);

    // Update the next scheduled time in the database
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
   * Initializes scheduled refreshes for all users.
   *
   * @param {number} intervalHours The interval in hours (default: 12).
   * @returns {Promise<void>}
   */
  async initializeScheduledRefreshes(intervalHours = 12) {
    try {
      const userIds = await refreshQueries.getAllUserIds();

      for (const userId of userIds) {
        // Schedule with random offset to avoid all users refreshing at same time
        const randomOffset = Math.floor(Math.random() * 60); // Random minutes
        const adjustedInterval = intervalHours + randomOffset / 60;

        await this.scheduleNextRefresh(userId, adjustedInterval);
        logger.info(`Initialized scheduled refresh for user ${userId}`);
      }

      logger.info(
        `Scheduled refreshes initialized for ${userIds.length} users`
      );
    } catch (err) {
      logger.error(`Failed to initialize scheduled refreshes: ${err.message}`);
      throw err;
    }
  }
}

// Create singleton instance
const refreshService = new RefreshService();

module.exports = refreshService;
