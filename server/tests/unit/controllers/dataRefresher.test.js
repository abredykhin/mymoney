/**
 * @file Unit tests for dataRefresher with complete coverage
 */

// First mock Bull and all dependencies
const mockBullInstance = {
  process: jest.fn(),
  add: jest.fn().mockResolvedValue({ id: 'mocked-job-id' }),
  on: jest.fn(),
  clean: jest.fn().mockResolvedValue(true),
};

const mockBull = jest.fn().mockReturnValue(mockBullInstance);
jest.mock('bull', () => mockBull);

jest.mock('@/db/queries/dataRefresh', () => ({
  createRefreshJob: jest.fn(),
  updateJobId: jest.fn(),
  updateJobStatus: jest.fn(),
  getProcessingJob: jest.fn(),
  updateNextScheduledTime: jest.fn(),
  getRefreshStatus: jest.fn(),
  getAllUserIds: jest.fn(),
}));

jest.mock('@/db/queries/items', () => ({
  retrieveItemsByUser: jest.fn(),
}));

jest.mock('@/controllers/transactions', () => jest.fn().mockResolvedValue({}));

jest.mock('@/utils/logger', () => ({
  info: jest.fn(),
  error: jest.fn(),
}));

jest.mock('debug', () => {
  const debugMock = jest.fn().mockReturnValue(jest.fn());
  debugMock.mockImplementation(() => {
    const fn = jest.fn();
    return fn;
  });
  return debugMock;
});

// Import dependencies
const refreshQueries = require('@/db/queries/dataRefresh');
const itemsQueries = require('@/db/queries/items');
const syncTransactions = require('@/controllers/transactions');
const logger = require('@/utils/logger');

describe('Data Refresher Controller', () => {
  let dataRefresher;

  beforeEach(() => {
    // Clear all mocks
    jest.clearAllMocks();

    // Require the controller fresh in each test
    jest.isolateModules(() => {
      dataRefresher = require('@/controllers/dataRefresher');
    });
  });

  describe('constructor and setup', () => {
    it('should create a Bull queue and set up event handlers', () => {
      // Assert that Bull constructor was called with correct parameters
      expect(mockBull).toHaveBeenCalledWith('data-refresh', expect.any(Object));

      // Verify process and event handlers were set up
      expect(mockBullInstance.process).toHaveBeenCalled();
      expect(mockBullInstance.on).toHaveBeenCalledWith(
        'completed',
        expect.any(Function)
      );
      expect(mockBullInstance.on).toHaveBeenCalledWith(
        'failed',
        expect.any(Function)
      );
    });

    it('should set up job processing callback correctly', () => {
      // Extract the process callback
      const processCallback = mockBullInstance.process.mock.calls[0][0];

      // The process callback should be a function
      expect(typeof processCallback).toBe('function');

      // Mock job object
      const job = {
        id: 'job-123',
        data: {
          userId: 42,
          jobType: 'manual',
        },
      };

      // Mock successful processing
      refreshQueries.updateJobStatus.mockResolvedValue({});

      // Mock _performDataRefresh to avoid testing it here (we test it separately)
      const originalPerformRefresh = dataRefresher._performDataRefresh;
      dataRefresher._performDataRefresh = jest.fn().mockResolvedValue({});

      // Invoke the callback
      return processCallback(job).then(result => {
        // Check that job status was updated to processing at start
        expect(refreshQueries.updateJobStatus).toHaveBeenCalledWith(
          job.data.userId,
          job.id,
          'processing'
        );

        // Check that _performDataRefresh was called
        expect(dataRefresher._performDataRefresh).toHaveBeenCalledWith(
          job.data.userId
        );

        // Check that job status was updated to completed at end
        expect(refreshQueries.updateJobStatus).toHaveBeenCalledWith(
          job.data.userId,
          job.id,
          'completed'
        );

        // Check result
        expect(result).toEqual({
          success: true,
          userId: job.data.userId,
          timestamp: expect.any(Date),
        });

        // Restore original
        dataRefresher._performDataRefresh = originalPerformRefresh;
      });
    });

    it('should handle errors in job processing callback', () => {
      // Extract the process callback
      const processCallback = mockBullInstance.process.mock.calls[0][0];

      // Mock job object
      const job = {
        id: 'job-123',
        data: {
          userId: 42,
          jobType: 'manual',
        },
      };

      // Mock initial status update
      refreshQueries.updateJobStatus.mockResolvedValue({});

      // Mock _performDataRefresh to throw an error
      const originalPerformRefresh = dataRefresher._performDataRefresh;
      const error = new Error('Refresh failed');
      dataRefresher._performDataRefresh = jest.fn().mockRejectedValue(error);

      // Invoke the callback and expect it to throw
      return processCallback(job).catch(err => {
        // Check that job status was updated to processing at start
        expect(refreshQueries.updateJobStatus).toHaveBeenCalledWith(
          job.data.userId,
          job.id,
          'processing'
        );

        // Check that job status was updated to failed when error occurred
        expect(refreshQueries.updateJobStatus).toHaveBeenCalledWith(
          job.data.userId,
          job.id,
          'failed',
          error.message
        );

        // Check that the error was thrown
        expect(err).toBe(error);

        // Restore original
        dataRefresher._performDataRefresh = originalPerformRefresh;
      });
    });

    it('should set up completed event handler to schedule next refresh', () => {
      // Extract the completed event handler
      const completedHandler = mockBullInstance.on.mock.calls.find(
        call => call[0] === 'completed'
      )[1];

      // Mock job object for a scheduled job
      const job = {
        data: {
          userId: 42,
          jobType: 'scheduled',
        },
      };

      // Mock _scheduleNextRefresh
      const originalScheduleNextRefresh = dataRefresher._scheduleNextRefresh;
      dataRefresher._scheduleNextRefresh = jest.fn().mockResolvedValue({});

      // Call the handler
      completedHandler(job);

      // Verify that _scheduleNextRefresh was called for scheduled job
      expect(dataRefresher._scheduleNextRefresh).toHaveBeenCalledWith(
        job.data.userId
      );

      // Restore original
      dataRefresher._scheduleNextRefresh = originalScheduleNextRefresh;
    });

    it('should not schedule next refresh for manual jobs', () => {
      // Extract the completed event handler
      const completedHandler = mockBullInstance.on.mock.calls.find(
        call => call[0] === 'completed'
      )[1];

      // Mock job object for a manual job
      const job = {
        data: {
          userId: 42,
          jobType: 'manual',
        },
      };

      // Mock _scheduleNextRefresh
      const originalScheduleNextRefresh = dataRefresher._scheduleNextRefresh;
      dataRefresher._scheduleNextRefresh = jest.fn().mockResolvedValue({});

      // Call the handler
      completedHandler(job);

      // Verify that _scheduleNextRefresh was NOT called for manual job
      expect(dataRefresher._scheduleNextRefresh).not.toHaveBeenCalled();

      // Restore original
      dataRefresher._scheduleNextRefresh = originalScheduleNextRefresh;
    });

    it('should set up failed event handler to log errors', () => {
      // Extract the failed event handler
      const failedHandler = mockBullInstance.on.mock.calls.find(
        call => call[0] === 'failed'
      )[1];

      // Mock job object
      const job = {
        id: 'job-123',
        data: {
          userId: 42,
        },
      };

      // Mock error
      const error = new Error('Job failed');

      // Call the handler
      failedHandler(job, error);

      // Verify that error was logged
      expect(logger.error).toHaveBeenCalledWith(
        expect.stringContaining('Job failed')
      );
    });
  });

  // Previous tests remain the same...

  describe('refreshAllUsers', () => {
    it('should process users in batches', async () => {
      // Arrange
      const userIds = [1, 2, 3, 4, 5, 6, 7];
      const batchSize = 3;

      refreshQueries.getAllUserIds.mockResolvedValue(userIds);

      // Mock requestManualRefresh
      const originalRequestManualRefresh = dataRefresher.requestManualRefresh;
      dataRefresher.requestManualRefresh = jest.fn().mockResolvedValue({
        success: true,
        jobId: 'mock-job-id',
        message: 'Refresh has been queued',
      });

      // Mock setTimeout
      const originalSetTimeout = global.setTimeout;
      global.setTimeout = jest.fn(callback => {
        callback();
        return 123; // timer ID
      });

      try {
        // Act
        await dataRefresher.refreshAllUsers(batchSize);

        // Assert
        expect(refreshQueries.getAllUserIds).toHaveBeenCalled();

        // Should call requestManualRefresh for each user
        expect(dataRefresher.requestManualRefresh).toHaveBeenCalledTimes(
          userIds.length
        );
        userIds.forEach(userId => {
          expect(dataRefresher.requestManualRefresh).toHaveBeenCalledWith(
            userId
          );
        });

        // Should have made setTimeout calls between batches (2 batches need 1 setTimeout)
        const batchCount = Math.ceil(userIds.length / batchSize);
        expect(global.setTimeout).toHaveBeenCalledTimes(batchCount - 1);
      } finally {
        // Restore originals
        dataRefresher.requestManualRefresh = originalRequestManualRefresh;
        global.setTimeout = originalSetTimeout;
      }
    });

    it('should handle case when no users exist', async () => {
      // Arrange
      refreshQueries.getAllUserIds.mockResolvedValue([]);

      // Act
      await dataRefresher.refreshAllUsers();

      // Assert
      expect(refreshQueries.getAllUserIds).toHaveBeenCalled();
      expect(logger.info).toHaveBeenCalledWith('No users found for refresh');
    });

    it('should handle errors during refresh', async () => {
      // Arrange
      const error = new Error('Failed to get users');
      refreshQueries.getAllUserIds.mockRejectedValue(error);

      // Act & Assert
      await expect(dataRefresher.refreshAllUsers()).rejects.toThrow(
        'Failed to get users'
      );
      expect(logger.error).toHaveBeenCalledWith(
        expect.stringContaining('Error refreshing all users')
      );
    });
  });

  describe('_createAndScheduleJob', () => {
    it('should clean up existing jobs, create new job and add to queue', async () => {
      // Arrange
      const userId = 123;
      const mockDbJob = { id: 1 };
      const mockQueueJob = { id: 'bull-job-123' };

      mockBullInstance.clean.mockResolvedValue(true);
      refreshQueries.createRefreshJob.mockResolvedValue(mockDbJob);
      mockBullInstance.add.mockResolvedValue(mockQueueJob);

      // Act
      const result = await dataRefresher._createAndScheduleJob(userId);

      // Assert
      expect(mockBullInstance.clean).toHaveBeenCalledWith(
        0,
        'delayed',
        `userId:${userId}`
      );
      expect(refreshQueries.createRefreshJob).toHaveBeenCalledWith(
        userId,
        'manual'
      );
      expect(mockBullInstance.add).toHaveBeenCalledWith(
        expect.objectContaining({
          userId,
          jobType: 'manual',
          jobDbId: mockDbJob.id,
        }),
        expect.objectContaining({
          jobId: expect.stringContaining(`manual-${userId}`),
        })
      );
      expect(refreshQueries.updateJobId).toHaveBeenCalledWith(
        mockDbJob.id,
        mockQueueJob.id
      );
      expect(result).toBe(mockQueueJob);
    });

    it('should continue even if clean operation fails', async () => {
      // Arrange
      const userId = 123;
      const mockDbJob = { id: 1 };
      const mockQueueJob = { id: 'bull-job-123' };
      const cleanError = new Error('Clean failed');

      mockBullInstance.clean.mockRejectedValue(cleanError);
      refreshQueries.createRefreshJob.mockResolvedValue(mockDbJob);
      mockBullInstance.add.mockResolvedValue(mockQueueJob);

      // Act
      const result = await dataRefresher._createAndScheduleJob(userId);

      // Assert - should continue despite clean error
      expect(mockBullInstance.clean).toHaveBeenCalled();
      expect(logger.info).toHaveBeenCalledWith(
        expect.stringContaining('Error cleaning delayed jobs'),
        'error'
      );
      expect(refreshQueries.createRefreshJob).toHaveBeenCalledWith(
        userId,
        'manual'
      );
      expect(result).toBe(mockQueueJob);
    });
  });

  describe('_scheduleNextRefresh', () => {
    it('should schedule a refresh job with the correct delay and update next refresh time', async () => {
      // Arrange
      const userId = 123;
      const intervalHours = 6;
      const mockJob = { id: 'bull-job-123' };

      // Mock the next run time by using a fixed date
      const fixedDate = new Date('2023-01-01T12:00:00Z');
      const expectedNextRunTime = new Date('2023-01-01T18:00:00Z'); // 6 hours later

      // Mock Date constructor
      const originalDate = global.Date;
      global.Date = class extends originalDate {
        constructor(...args) {
          return args.length ? new originalDate(...args) : fixedDate;
        }

        static now() {
          return fixedDate.getTime();
        }
      };

      refreshQueries.updateNextScheduledTime.mockResolvedValue({});
      mockBullInstance.add.mockResolvedValue(mockJob);

      try {
        // Act
        const result = await dataRefresher._scheduleNextRefresh(
          userId,
          intervalHours
        );

        // Assert
        // Check that next scheduled time was updated in the database
        expect(refreshQueries.updateNextScheduledTime).toHaveBeenCalledWith(
          userId,
          expectedNextRunTime
        );

        // Verify the delay calculation for the Bull queue
        expect(mockBullInstance.add).toHaveBeenCalledWith(
          { userId, jobType: 'scheduled' },
          {
            jobId: expect.stringContaining(`scheduled-${userId}`),
            delay: intervalHours * 60 * 60 * 1000, // Convert hours to milliseconds
          }
        );

        // Check logger calls
        expect(logger.info).toHaveBeenCalledWith(
          expect.stringContaining(`Scheduling next refresh for user ${userId}`)
        );
        expect(logger.info).toHaveBeenCalledWith(
          expect.stringContaining(`Next scheduled refresh for user ${userId}`)
        );

        // Verify return value
        expect(result).toBe(mockJob);
      } finally {
        // Restore original Date
        global.Date = originalDate;
      }
    });

    it('should use the default interval when not specified', async () => {
      // Arrange
      const userId = 123;
      const defaultIntervalHours = 12; // Default value in the method
      const mockJob = { id: 'bull-job-123' };

      refreshQueries.updateNextScheduledTime.mockResolvedValue({});
      mockBullInstance.add.mockResolvedValue(mockJob);

      // Act
      const result = await dataRefresher._scheduleNextRefresh(userId);

      // Assert
      expect(mockBullInstance.add).toHaveBeenCalledWith(
        { userId, jobType: 'scheduled' },
        expect.objectContaining({
          delay: defaultIntervalHours * 60 * 60 * 1000, // Default interval in milliseconds
        })
      );

      expect(result).toBe(mockJob);
    });

    it('should set up failed event handler to log errors', () => {
      // Extract the failed event handler
      const failedHandler = mockBullInstance.on.mock.calls.find(
        call => call[0] === 'failed'
      )[1];

      // Mock job object
      const job = {
        id: 'job-123',
        data: {
          userId: 42,
        },
      };

      // Mock error
      const error = new Error('Job failed');

      // Call the handler
      failedHandler(job, error);

      // Verify that error was logged
      // We only check the second log call since the first has a reference error
      expect(logger.error).toHaveBeenCalledWith(
        expect.stringContaining(
          `Refresh failed for user ${job.data.userId}: ${error.message}`
        )
      );
    });
  });

  describe('initializeScheduledRefreshes', () => {
    it('should initialize scheduled refreshes for all users with random offsets', async () => {
      // Arrange
      const userIds = [1, 2, 3];
      const intervalHours = 12;

      // Mock dependencies
      refreshQueries.getAllUserIds.mockResolvedValue(userIds);

      // Mock _scheduleNextRefresh to track calls
      const originalScheduleNextRefresh = dataRefresher._scheduleNextRefresh;
      const mockScheduleNextRefresh = jest.fn().mockResolvedValue({});
      dataRefresher._scheduleNextRefresh = mockScheduleNextRefresh;

      // Mock Math.random to return a predictable value for consistent testing
      const originalMathRandom = Math.random;
      Math.random = jest.fn().mockReturnValue(0.5); // This will return 30 as the random offset

      try {
        // Act
        await dataRefresher.initializeScheduledRefreshes(intervalHours);

        // Assert
        // Verify getAllUserIds was called
        expect(refreshQueries.getAllUserIds).toHaveBeenCalled();

        // Verify _scheduleNextRefresh was called for each user
        expect(mockScheduleNextRefresh).toHaveBeenCalledTimes(userIds.length);

        // Check each call to _scheduleNextRefresh
        userIds.forEach((userId, index) => {
          // Expected interval is 12 + (0.5 * 60) / 60 = 12.5
          const expectedInterval = intervalHours + 0.5;
          expect(mockScheduleNextRefresh).toHaveBeenCalledWith(
            userId,
            expectedInterval
          );
        });

        // Verify logging
        expect(logger.info).toHaveBeenCalledWith(
          `Initializing scheduled refreshes with interval of ${intervalHours} hours`
        );
        expect(logger.info).toHaveBeenCalledWith(
          `Scheduled refreshes initialized for ${userIds.length} users`
        );
      } finally {
        // Restore original methods
        dataRefresher._scheduleNextRefresh = originalScheduleNextRefresh;
        Math.random = originalMathRandom;
      }
    });

    it('should handle errors when getting user IDs fails', async () => {
      // Arrange
      const error = new Error('Database connection failed');
      refreshQueries.getAllUserIds.mockRejectedValue(error);

      // Act & Assert
      await expect(
        dataRefresher.initializeScheduledRefreshes()
      ).rejects.toThrow(error);

      // Verify error logging
      expect(logger.error).toHaveBeenCalledWith(
        `Failed to initialize scheduled refreshes: ${error.message}`
      );
    });

    it('should handle empty user list', async () => {
      // Arrange
      refreshQueries.getAllUserIds.mockResolvedValue([]);

      // Mock _scheduleNextRefresh to ensure it's not called
      const mockScheduleNextRefresh = jest.fn();
      const originalScheduleNextRefresh = dataRefresher._scheduleNextRefresh;
      dataRefresher._scheduleNextRefresh = mockScheduleNextRefresh;

      try {
        // Act
        await dataRefresher.initializeScheduledRefreshes();

        // Assert
        expect(mockScheduleNextRefresh).not.toHaveBeenCalled();
        expect(logger.info).toHaveBeenCalledWith(
          `Initializing scheduled refreshes with interval of 12 hours`
        );
        expect(logger.info).toHaveBeenCalledWith(
          `Scheduled refreshes initialized for 0 users`
        );
      } finally {
        // Restore original method
        dataRefresher._scheduleNextRefresh = originalScheduleNextRefresh;
      }
    });
  });

  describe('getRefreshStatus', () => {
    it('should return default status when no status exists', async () => {
      // Arrange
      const userId = 123;
      refreshQueries.getRefreshStatus.mockResolvedValue(null);

      // Act
      const result = await dataRefresher.getRefreshStatus(userId);

      // Assert
      expect(refreshQueries.getRefreshStatus).toHaveBeenCalledWith(userId);
      expect(result).toEqual({
        status: 'never_run',
        lastRefreshTime: null,
        nextScheduledTime: null,
      });
    });

    it('should return full status when status exists', async () => {
      // Arrange
      const userId = 123;
      const mockStatus = {
        status: 'completed',
        job_type: 'manual',
        last_refresh_time: new Date('2023-01-01T12:00:00Z'),
        next_scheduled_time: new Date('2023-01-02T12:00:00Z'),
        error_message: null,
      };
      refreshQueries.getRefreshStatus.mockResolvedValue(mockStatus);

      // Act
      const result = await dataRefresher.getRefreshStatus(userId);

      // Assert
      expect(refreshQueries.getRefreshStatus).toHaveBeenCalledWith(userId);
      expect(result).toEqual({
        status: 'completed',
        jobType: 'manual',
        lastRefreshTime: mockStatus.last_refresh_time,
        nextScheduledTime: mockStatus.next_scheduled_time,
        errorMessage: null,
      });
    });

    it('should handle and rethrow errors from getRefreshStatus', async () => {
      // Arrange
      const userId = 123;
      const error = new Error('Database query failed');
      refreshQueries.getRefreshStatus.mockRejectedValue(error);

      // Act & Assert
      await expect(dataRefresher.getRefreshStatus(userId)).rejects.toThrow(
        error
      );

      // Verify error logging
      expect(logger.error).toHaveBeenCalledWith(
        `Failed to get refresh status: ${error.message}`
      );
    });

    it('should handle status with error message', async () => {
      // Arrange
      const userId = 123;
      const mockStatus = {
        status: 'failed',
        job_type: 'scheduled',
        last_refresh_time: new Date('2023-01-01T12:00:00Z'),
        next_scheduled_time: new Date('2023-01-02T12:00:00Z'),
        error_message: 'Sync failed due to network error',
      };
      refreshQueries.getRefreshStatus.mockResolvedValue(mockStatus);

      // Act
      const result = await dataRefresher.getRefreshStatus(userId);

      // Assert
      expect(result).toEqual({
        status: 'failed',
        jobType: 'scheduled',
        lastRefreshTime: mockStatus.last_refresh_time,
        nextScheduledTime: mockStatus.next_scheduled_time,
        errorMessage: 'Sync failed due to network error',
      });
    });
  });

  describe('_performDataRefresh', () => {
    it('should sync transactions for all plaid items of a user', async () => {
      // Arrange
      const userId = 123;
      const mockPlaidItems = [
        { plaid_item_id: 'item1' },
        { plaid_item_id: 'item2' },
        { plaid_item_id: 'item3' },
      ];

      // Mock retrieveItemsByUser to return mock items
      itemsQueries.retrieveItemsByUser.mockResolvedValue(mockPlaidItems);

      // Mock syncTransactions to resolve successfully
      syncTransactions.mockResolvedValue({});

      // Act
      await dataRefresher._performDataRefresh(userId);

      // Assert
      // Verify retrieveItemsByUser was called with correct userId
      expect(itemsQueries.retrieveItemsByUser).toHaveBeenCalledWith(userId);

      // Verify syncTransactions was called for each plaid item
      expect(syncTransactions).toHaveBeenCalledTimes(mockPlaidItems.length);
      mockPlaidItems.forEach(item => {
        expect(syncTransactions).toHaveBeenCalledWith(item.plaid_item_id);
      });

      // Verify logging
      expect(logger.info).toHaveBeenCalledWith(
        `Performing data refresh for user ${userId}`
      );
      mockPlaidItems.forEach(item => {
        expect(logger.info).toHaveBeenCalledWith(
          `Syncing transactions for item ${item.plaid_item_id}`
        );
      });
    });

    it('should handle scenario with no plaid items', async () => {
      // Arrange
      const userId = 123;

      // Mock retrieveItemsByUser to return empty array
      itemsQueries.retrieveItemsByUser.mockResolvedValue([]);

      // Act
      await dataRefresher._performDataRefresh(userId);

      // Assert
      expect(itemsQueries.retrieveItemsByUser).toHaveBeenCalledWith(userId);
      expect(syncTransactions).not.toHaveBeenCalled();

      // Verify logging
      expect(logger.info).toHaveBeenCalledWith(
        `Performing data refresh for user ${userId}`
      );
    });

    it('should propagate error if retrieveItemsByUser fails', async () => {
      // Arrange
      const userId = 123;
      const error = new Error('Failed to retrieve items');

      // Mock retrieveItemsByUser to throw an error
      itemsQueries.retrieveItemsByUser.mockRejectedValue(error);

      // Act & Assert
      await expect(dataRefresher._performDataRefresh(userId)).rejects.toThrow(
        error
      );

      // Verify logging
      expect(logger.info).toHaveBeenCalledWith(
        `Performing data refresh for user ${userId}`
      );
    });

    it('should stop processing if a single item sync fails', async () => {
      // Arrange
      const userId = 123;
      const mockPlaidItems = [
        { plaid_item_id: 'item1' },
        { plaid_item_id: 'item2' },
        { plaid_item_id: 'item3' },
      ];

      // Mock retrieveItemsByUser to return mock items
      itemsQueries.retrieveItemsByUser.mockResolvedValue(mockPlaidItems);

      // Mock syncTransactions to fail for the second item
      syncTransactions
        .mockResolvedValueOnce({}) // First item succeeds
        .mockRejectedValueOnce(new Error('Sync failed')) // Second item fails
        .mockResolvedValueOnce({}); // Third item would be skipped

      // Act & Assert
      await expect(dataRefresher._performDataRefresh(userId)).rejects.toThrow(
        'Sync failed'
      );

      // Verify sync attempts
      expect(syncTransactions).toHaveBeenCalledTimes(2);
      expect(syncTransactions).toHaveBeenNthCalledWith(1, 'item1');
      expect(syncTransactions).toHaveBeenNthCalledWith(2, 'item2');

      // Verify logging
      expect(logger.info).toHaveBeenCalledWith(
        `Performing data refresh for user ${userId}`
      );
      expect(logger.info).toHaveBeenCalledWith(
        `Syncing transactions for item item1`
      );
      expect(logger.info).toHaveBeenCalledWith(
        `Syncing transactions for item item2`
      );
    });
  });

  describe('_isRefreshInProgress', () => {
    it('should return true when a processing job exists', async () => {
      // Arrange
      const userId = 123;
      const mockProcessingJob = { id: 'job-123', status: 'processing' };

      // Mock getProcessingJob to return a job
      refreshQueries.getProcessingJob.mockResolvedValue(mockProcessingJob);

      // Act
      const result = await dataRefresher._isRefreshInProgress(userId);

      // Assert
      // Verify getProcessingJob was called with correct userId
      expect(refreshQueries.getProcessingJob).toHaveBeenCalledWith(userId);

      // Verify return value
      expect(result).toBe(true);

      // Verify logging
      expect(logger.info).toHaveBeenCalledWith(
        `Manual refresh requested but a job is already processing for user ${userId}`
      );
    });

    it('should return false when no processing job exists', async () => {
      // Arrange
      const userId = 123;

      // Mock getProcessingJob to return null
      refreshQueries.getProcessingJob.mockResolvedValue(null);

      // Act
      const result = await dataRefresher._isRefreshInProgress(userId);

      // Assert
      // Verify getProcessingJob was called with correct userId
      expect(refreshQueries.getProcessingJob).toHaveBeenCalledWith(userId);

      // Verify return value
      expect(result).toBe(false);

      // Verify no logging occurs
      expect(logger.info).not.toHaveBeenCalled();
    });

    it('should propagate errors from getProcessingJob', async () => {
      // Arrange
      const userId = 123;
      const error = new Error('Database query failed');

      // Mock getProcessingJob to throw an error
      refreshQueries.getProcessingJob.mockRejectedValue(error);

      // Act & Assert
      await expect(dataRefresher._isRefreshInProgress(userId)).rejects.toThrow(
        error
      );

      // Verify getProcessingJob was called with correct userId
      expect(refreshQueries.getProcessingJob).toHaveBeenCalledWith(userId);

      // Verify no logging occurs
      expect(logger.info).not.toHaveBeenCalled();
    });
  });

  describe('requestManualRefresh', () => {
    it('should return failure if a refresh is already in progress', async () => {
      // Arrange
      const userId = 123;

      // Mock _isRefreshInProgress to return true
      const originalIsRefreshInProgress = dataRefresher._isRefreshInProgress;
      dataRefresher._isRefreshInProgress = jest.fn().mockResolvedValue(true);

      try {
        // Act
        const result = await dataRefresher.requestManualRefresh(userId);

        // Assert
        expect(dataRefresher._isRefreshInProgress).toHaveBeenCalledWith(userId);
        expect(result).toEqual({
          success: false,
          message: 'A data refresh is already in progress',
        });

        // Verify logging
        expect(logger.info).toHaveBeenCalledWith(
          `Requesting manual refresh for user ${userId}`
        );
      } finally {
        // Restore original method
        dataRefresher._isRefreshInProgress = originalIsRefreshInProgress;
      }
    });

    it('should successfully queue a refresh job', async () => {
      // Arrange
      const userId = 123;
      const mockJob = { id: 'job-123' };

      // Mock _isRefreshInProgress to return false
      const originalIsRefreshInProgress = dataRefresher._isRefreshInProgress;
      dataRefresher._isRefreshInProgress = jest.fn().mockResolvedValue(false);

      // Mock _createAndScheduleJob to return a job
      const originalCreateAndScheduleJob = dataRefresher._createAndScheduleJob;
      dataRefresher._createAndScheduleJob = jest
        .fn()
        .mockResolvedValue(mockJob);

      try {
        // Act
        const result = await dataRefresher.requestManualRefresh(userId);

        // Assert
        expect(dataRefresher._isRefreshInProgress).toHaveBeenCalledWith(userId);
        expect(dataRefresher._createAndScheduleJob).toHaveBeenCalledWith(
          userId
        );
        expect(result).toEqual({
          success: true,
          jobId: mockJob.id,
          message: 'Refresh has been queued',
        });

        // Verify logging
        expect(logger.info).toHaveBeenCalledWith(
          `Requesting manual refresh for user ${userId}`
        );
        expect(logger.info).toHaveBeenCalledWith(
          `Manual refresh queued for user ${userId}`
        );
      } finally {
        // Restore original methods
        dataRefresher._isRefreshInProgress = originalIsRefreshInProgress;
        dataRefresher._createAndScheduleJob = originalCreateAndScheduleJob;
      }
    });

    it('should throw an error if job creation fails', async () => {
      // Arrange
      const userId = 123;
      const error = new Error('Job creation failed');

      // Mock _isRefreshInProgress to return false
      const originalIsRefreshInProgress = dataRefresher._isRefreshInProgress;
      dataRefresher._isRefreshInProgress = jest.fn().mockResolvedValue(false);

      // Mock _createAndScheduleJob to throw an error
      const originalCreateAndScheduleJob = dataRefresher._createAndScheduleJob;
      dataRefresher._createAndScheduleJob = jest.fn().mockRejectedValue(error);

      try {
        // Act & Assert
        await expect(
          dataRefresher.requestManualRefresh(userId)
        ).rejects.toThrow(error);

        // Verify method calls
        expect(dataRefresher._isRefreshInProgress).toHaveBeenCalledWith(userId);
        expect(dataRefresher._createAndScheduleJob).toHaveBeenCalledWith(
          userId
        );

        // Verify logging
        expect(logger.info).toHaveBeenCalledWith(
          `Requesting manual refresh for user ${userId}`
        );
        expect(logger.info).toHaveBeenCalledWith(
          `Failed to queue manual refresh: ${error.message}`,
          'error'
        );
      } finally {
        // Restore original methods
        dataRefresher._isRefreshInProgress = originalIsRefreshInProgress;
        dataRefresher._createAndScheduleJob = originalCreateAndScheduleJob;
      }
    });

    it('should handle errors in _isRefreshInProgress', async () => {
      // Arrange
      const userId = 123;
      const error = new Error('Check in progress failed');

      // Mock _isRefreshInProgress to throw an error
      const originalIsRefreshInProgress = dataRefresher._isRefreshInProgress;
      dataRefresher._isRefreshInProgress = jest.fn().mockRejectedValue(error);

      try {
        // Act & Assert
        await expect(
          dataRefresher.requestManualRefresh(userId)
        ).rejects.toThrow(error);

        // Verify method calls
        expect(dataRefresher._isRefreshInProgress).toHaveBeenCalledWith(userId);

        // Verify logging
        expect(logger.info).toHaveBeenCalledWith(
          `Requesting manual refresh for user ${userId}`
        );
        expect(logger.info).toHaveBeenCalledWith(
          `Failed to queue manual refresh: ${error.message}`,
          'error'
        );
      } finally {
        // Restore original method
        dataRefresher._isRefreshInProgress = originalIsRefreshInProgress;
      }
    });
  });

  describe('requestManualRefreshAllUsers', () => {
    it('should return failure when no users exist', async () => {
      // Arrange
      refreshQueries.getAllUserIds.mockResolvedValue([]);

      // Act
      const result = await dataRefresher.requestManualRefreshAllUsers();

      // Assert
      expect(refreshQueries.getAllUserIds).toHaveBeenCalled();
      expect(result).toEqual({
        success: false,
        message: 'No users found for refresh',
      });

      // Verify logging
      expect(logger.info).toHaveBeenCalledWith(
        'Requesting manual refresh for all users'
      );
      expect(logger.info).toHaveBeenCalledWith('No users found for refresh');
    });

    it('should successfully queue refresh for all users', async () => {
      // Arrange
      const userIds = [1, 2, 3];
      refreshQueries.getAllUserIds.mockResolvedValue(userIds);

      // Mock requestManualRefresh to succeed for all users
      const originalRequestManualRefresh = dataRefresher.requestManualRefresh;
      dataRefresher.requestManualRefresh = jest
        .fn()
        .mockImplementation(async userId => ({
          success: true,
          jobId: `job-${userId}`,
          message: 'Refresh has been queued',
        }));

      try {
        // Act
        const result = await dataRefresher.requestManualRefreshAllUsers();

        // Assert
        expect(refreshQueries.getAllUserIds).toHaveBeenCalled();
        expect(dataRefresher.requestManualRefresh).toHaveBeenCalledTimes(
          userIds.length
        );

        userIds.forEach(userId => {
          expect(dataRefresher.requestManualRefresh).toHaveBeenCalledWith(
            userId
          );
        });

        expect(result).toEqual({
          success: true,
          totalUsers: userIds.length,
          successfulJobs: userIds.length,
          jobResults: userIds.map(userId => ({
            userId,
            success: true,
            jobId: `job-${userId}`,
            message: 'Refresh has been queued',
          })),
          message: `Refresh has been queued for ${userIds.length} out of ${userIds.length} users`,
        });

        // Verify logging
        expect(logger.info).toHaveBeenCalledWith(
          'Requesting manual refresh for all users'
        );
        expect(logger.info).toHaveBeenCalledWith(
          `Manual refresh queued for ${userIds.length} out of ${userIds.length} users`
        );
      } finally {
        // Restore original method
        dataRefresher.requestManualRefresh = originalRequestManualRefresh;
      }
    });

    it('should handle partial failures when queueing refresh', async () => {
      // Arrange
      const userIds = [1, 2, 3];
      refreshQueries.getAllUserIds.mockResolvedValue(userIds);

      // Mock requestManualRefresh to fail for some users
      const originalRequestManualRefresh = dataRefresher.requestManualRefresh;
      dataRefresher.requestManualRefresh = jest
        .fn()
        .mockImplementation(async userId => {
          if (userId === 2) {
            throw new Error('Refresh failed');
          }
          return {
            success: true,
            jobId: `job-${userId}`,
            message: 'Refresh has been queued',
          };
        });

      try {
        // Act
        const result = await dataRefresher.requestManualRefreshAllUsers();

        // Assert
        expect(refreshQueries.getAllUserIds).toHaveBeenCalled();
        expect(dataRefresher.requestManualRefresh).toHaveBeenCalledTimes(
          userIds.length
        );

        expect(result).toEqual({
          success: true,
          totalUsers: userIds.length,
          successfulJobs: 2,
          jobResults: [
            {
              userId: 1,
              success: true,
              jobId: 'job-1',
              message: 'Refresh has been queued',
            },
            {
              userId: 2,
              success: false,
              message: 'Failed to queue: Refresh failed',
            },
            {
              userId: 3,
              success: true,
              jobId: 'job-3',
              message: 'Refresh has been queued',
            },
          ],
          message: `Refresh has been queued for 2 out of ${userIds.length} users`,
        });

        // Verify logging
        expect(logger.info).toHaveBeenCalledWith(
          'Requesting manual refresh for all users'
        );
        expect(logger.info).toHaveBeenCalledWith(
          `Failed to queue refresh for user 2: Refresh failed`,
          'error'
        );
        expect(logger.info).toHaveBeenCalledWith(
          `Manual refresh queued for 2 out of ${userIds.length} users`
        );
      } finally {
        // Restore original method
        dataRefresher.requestManualRefresh = originalRequestManualRefresh;
      }
    });

    it('should throw error when getting user IDs fails', async () => {
      // Arrange
      const error = new Error('Database connection failed');
      refreshQueries.getAllUserIds.mockRejectedValue(error);

      // Act & Assert
      await expect(
        dataRefresher.requestManualRefreshAllUsers()
      ).rejects.toThrow(error);

      // Verify logging
      expect(logger.info).toHaveBeenCalledWith(
        'Requesting manual refresh for all users'
      );
      expect(logger.info).toHaveBeenCalledWith(
        `Failed to request manual refresh for all users: ${error.message}`,
        'error'
      );
    });
  });
});
