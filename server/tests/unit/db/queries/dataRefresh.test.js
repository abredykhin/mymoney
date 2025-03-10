/**
 * @file Unit tests for refresh_jobs queries
 */
// Import the module to test
const refreshJobsQueries = require('@/db/queries/dataRefresh');

// Mock the database module
jest.mock('@/db', () => ({
  query: jest.fn(),
}));

// Mock the debug module
jest.mock('debug', () => () => jest.fn());

// Import the mocked modules
const db = require('@/db');

describe('Refresh Jobs Queries', () => {
  // Clear all mocks before each test
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createRefreshJob', () => {
    it('should create a new refresh job record', async () => {
      // Arrange
      const userId = 123;
      const jobType = 'manual';
      const now = new Date();

      const mockRefreshJob = {
        id: 1,
        user_id: userId,
        status: 'pending',
        job_type: jobType,
        job_id: null,
        last_refresh_time: null,
        next_scheduled_time: null,
        created_at: now,
        updated_at: now,
        error_message: null,
      };

      db.query.mockResolvedValueOnce({ rows: [mockRefreshJob] });

      // Act
      const result = await refreshJobsQueries.createRefreshJob(userId, jobType);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: expect.any(String),
        values: [userId, jobType],
      });

      // Verify the SQL contains the key parts we care about
      expect(db.query.mock.calls[0][0].text).toContain(
        'INSERT INTO refresh_jobs'
      );
      expect(result).toEqual(mockRefreshJob);
    });

    it('should throw an error if database query fails', async () => {
      // Arrange
      const userId = 123;
      const jobType = 'manual';
      const error = new Error('Database error');

      db.query.mockRejectedValueOnce(error);

      // Act & Assert
      await expect(
        refreshJobsQueries.createRefreshJob(userId, jobType)
      ).rejects.toThrow('Database error');
    });
  });

  describe('updateJobId', () => {
    it('should update a refresh job with the Bull queue job ID', async () => {
      // Arrange
      const jobDbId = 1;
      const bullJobId = 'bull-123';

      const mockUpdatedJob = {
        id: jobDbId,
        user_id: 123,
        status: 'pending',
        job_type: 'manual',
        job_id: bullJobId,
        last_refresh_time: null,
        next_scheduled_time: null,
        created_at: new Date(),
        updated_at: new Date(),
        error_message: null,
      };

      db.query.mockResolvedValueOnce({ rows: [mockUpdatedJob] });

      // Act
      const result = await refreshJobsQueries.updateJobId(jobDbId, bullJobId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'UPDATE refresh_jobs SET job_id = $1 WHERE id = $2 RETURNING *;',
        values: [bullJobId, jobDbId],
      });
      expect(result).toEqual(mockUpdatedJob);
    });
  });

  describe('updateJobStatus', () => {
    it('should update the status to processing', async () => {
      // Arrange
      const userId = 123;
      const jobId = 'bull-123';
      const status = 'processing';

      const mockUpdatedJob = {
        id: 1,
        user_id: userId,
        status: status,
        job_type: 'manual',
        job_id: jobId,
        last_refresh_time: null,
        next_scheduled_time: null,
        created_at: new Date(),
        updated_at: new Date(),
        error_message: null,
      };

      db.query.mockResolvedValueOnce({ rows: [mockUpdatedJob] });

      // Act
      const result = await refreshJobsQueries.updateJobStatus(
        userId,
        jobId,
        status
      );

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: expect.any(String),
        values: [status, userId, jobId, null],
      });

      // Verify the SQL contains the key parts we care about
      expect(db.query.mock.calls[0][0].text).toContain('UPDATE refresh_jobs');
      expect(db.query.mock.calls[0][0].text).toContain('SET status = $1');
      expect(result).toEqual(mockUpdatedJob);
    });

    it('should update the status to completed and set last_refresh_time', async () => {
      // Arrange
      const userId = 123;
      const jobId = 'bull-123';
      const status = 'completed';

      const mockUpdatedJob = {
        id: 1,
        user_id: userId,
        status: status,
        job_type: 'manual',
        job_id: jobId,
        last_refresh_time: new Date(),
        next_scheduled_time: null,
        created_at: new Date(),
        updated_at: new Date(),
        error_message: null,
      };

      db.query.mockResolvedValueOnce({ rows: [mockUpdatedJob] });

      // Act
      const result = await refreshJobsQueries.updateJobStatus(
        userId,
        jobId,
        status
      );

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: expect.any(String),
        values: [status, userId, jobId, null],
      });

      // Verify the SQL contains the key parts we care about
      expect(db.query.mock.calls[0][0].text).toContain('UPDATE refresh_jobs');
      expect(db.query.mock.calls[0][0].text).toContain(
        'last_refresh_time = NOW()'
      );
      expect(result).toEqual(mockUpdatedJob);
    });

    it('should update the status to failed with error message', async () => {
      // Arrange
      const userId = 123;
      const jobId = 'bull-123';
      const status = 'failed';
      const errorMessage = 'Connection timeout';

      const mockUpdatedJob = {
        id: 1,
        user_id: userId,
        status: status,
        job_type: 'manual',
        job_id: jobId,
        last_refresh_time: null,
        next_scheduled_time: null,
        created_at: new Date(),
        updated_at: new Date(),
        error_message: errorMessage,
      };

      db.query.mockResolvedValueOnce({ rows: [mockUpdatedJob] });

      // Act
      const result = await refreshJobsQueries.updateJobStatus(
        userId,
        jobId,
        status,
        errorMessage
      );

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: expect.any(String),
        values: [status, userId, jobId, errorMessage],
      });

      // Verify the SQL contains the key parts we care about
      expect(db.query.mock.calls[0][0].text).toContain('UPDATE refresh_jobs');
      expect(db.query.mock.calls[0][0].text).toContain('SET status = $1');
      expect(db.query.mock.calls[0][0].text).toContain('error_message = $4');
      expect(result).toEqual(mockUpdatedJob);
    });
  });

  describe('getProcessingJob', () => {
    it('should get a processing job for a user', async () => {
      // Arrange
      const userId = 123;

      const mockProcessingJob = {
        id: 1,
        user_id: userId,
        status: 'processing',
        job_type: 'manual',
        job_id: 'bull-123',
        last_refresh_time: null,
        next_scheduled_time: null,
        created_at: new Date(),
        updated_at: new Date(),
        error_message: null,
      };

      db.query.mockResolvedValueOnce({ rows: [mockProcessingJob] });

      // Act
      const result = await refreshJobsQueries.getProcessingJob(userId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: expect.any(String),
        values: [userId],
      });

      // Verify the SQL contains the key parts we care about
      expect(db.query.mock.calls[0][0].text).toContain(
        "WHERE user_id = $1 AND status = 'processing'"
      );
      expect(result).toEqual(mockProcessingJob);
    });

    it('should return null if no processing job exists', async () => {
      // Arrange
      const userId = 123;

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await refreshJobsQueries.getProcessingJob(userId);

      // Assert
      expect(result).toBeNull();
    });
  });

  describe('updateNextScheduledTime', () => {
    it('should update the next scheduled refresh time', async () => {
      // Arrange
      const userId = 123;
      const nextScheduledTime = new Date();

      const mockUpdatedJob = {
        id: 1,
        user_id: userId,
        status: 'completed',
        job_type: 'scheduled',
        job_id: 'bull-123',
        last_refresh_time: new Date(),
        next_scheduled_time: nextScheduledTime,
        created_at: new Date(),
        updated_at: new Date(),
        error_message: null,
      };

      db.query.mockResolvedValueOnce({ rows: [mockUpdatedJob] });

      // Act
      const result = await refreshJobsQueries.updateNextScheduledTime(
        userId,
        nextScheduledTime
      );

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: expect.any(String),
        values: [userId, nextScheduledTime],
      });

      // Verify the SQL contains the key parts we care about
      expect(db.query.mock.calls[0][0].text).toContain('UPDATE refresh_jobs');
      expect(db.query.mock.calls[0][0].text).toContain(
        'SET next_scheduled_time = $2'
      );
      expect(result).toEqual(mockUpdatedJob);
    });
  });

  describe('getRefreshStatus', () => {
    it('should get the latest refresh status for a user', async () => {
      // Arrange
      const userId = 123;

      const mockRefreshJob = {
        id: 1,
        user_id: userId,
        status: 'completed',
        job_type: 'manual',
        job_id: 'bull-123',
        last_refresh_time: new Date(),
        next_scheduled_time: null,
        created_at: new Date(),
        updated_at: new Date(),
        error_message: null,
      };

      db.query.mockResolvedValueOnce({ rows: [mockRefreshJob] });

      // Act
      const result = await refreshJobsQueries.getRefreshStatus(userId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: expect.any(String),
        values: [userId],
      });

      // Verify the SQL contains the key parts we care about
      expect(db.query.mock.calls[0][0].text).toContain(
        'SELECT * FROM refresh_jobs'
      );
      expect(db.query.mock.calls[0][0].text).toContain('WHERE user_id = $1');
      expect(result).toEqual(mockRefreshJob);
    });

    it('should return null if no refresh jobs exist for the user', async () => {
      // Arrange
      const userId = 123;

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await refreshJobsQueries.getRefreshStatus(userId);

      // Assert
      expect(result).toBeNull();
    });
  });

  describe('getAllUserIds', () => {
    it('should get all user IDs from the users table', async () => {
      // Arrange
      const mockUserIds = [{ id: 1 }, { id: 2 }, { id: 3 }];

      db.query.mockResolvedValueOnce({ rows: mockUserIds });

      // Act
      const result = await refreshJobsQueries.getAllUserIds();

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT id FROM users_table;',
      });
      expect(result).toEqual([1, 2, 3]);
    });

    it('should return an empty array if no users exist', async () => {
      // Arrange
      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await refreshJobsQueries.getAllUserIds();

      // Assert
      expect(result).toEqual([]);
    });
  });
});
