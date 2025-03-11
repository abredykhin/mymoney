/**
 * @file Unit tests for sessions controller
 */

// Mock dependencies before importing controller
jest.mock('crypto', () => ({
  randomBytes: jest.fn().mockReturnValue({
    toString: jest.fn().mockReturnValue('mock-random-token'),
  }),
}));

jest.mock('@/db/queries/sessions', () => ({
  createSession: jest.fn(),
  expireToken: jest.fn(),
}));

jest.mock('debug', () => () => jest.fn());

// Import the module and mocked dependencies
const sessionsController = require('@/controllers/sessions');
const crypto = require('crypto');
const sessionsQueries = require('@/db/queries/sessions');

describe('Sessions Controller', () => {
  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
  });

  describe('initSession', () => {
    it('should generate a token and create a session for a user', async () => {
      // Arrange
      const userId = 123;
      const mockToken = 'mock-random-token';
      const mockSession = {
        session_id: 1,
        token: mockToken,
        user_id: userId,
        created_at: new Date(),
        status: 'valid',
      };

      // Set up the createSession mock to return the mock session
      sessionsQueries.createSession.mockResolvedValue(mockSession);

      // Act
      const result = await sessionsController.initSession(userId);

      // Assert
      // Verify token generation
      expect(crypto.randomBytes).toHaveBeenCalledWith(64);

      // Verify session creation in the database
      expect(sessionsQueries.createSession).toHaveBeenCalledWith(
        mockToken,
        userId
      );

      // Verify the returned session object
      expect(result).toEqual(mockSession);
    });

    it('should handle errors during session creation', async () => {
      // Arrange
      const userId = 123;
      const error = new Error('Database error');

      // Set up the createSession mock to throw an error
      sessionsQueries.createSession.mockRejectedValue(error);

      // Act & Assert
      await expect(sessionsController.initSession(userId)).rejects.toThrow(
        'Database error'
      );

      // Verify token generation was attempted
      expect(crypto.randomBytes).toHaveBeenCalledWith(64);

      // Verify session creation was attempted
      expect(sessionsQueries.createSession).toHaveBeenCalledWith(
        'mock-random-token',
        userId
      );
    });
  });

  describe('expireToken', () => {
    it('should expire a token', async () => {
      // Arrange
      const token = 'valid-token';

      // Set up the expireToken mock to resolve successfully
      sessionsQueries.expireToken.mockResolvedValue({ affected_rows: 1 });

      // Act
      await sessionsController.expireToken(token);

      // Assert
      expect(sessionsQueries.expireToken).toHaveBeenCalledWith(token);
    });

    it('should handle errors during token expiration', async () => {
      // Arrange
      const token = 'valid-token';
      const error = new Error('Database error');

      // Set up the expireToken mock to throw an error
      sessionsQueries.expireToken.mockRejectedValue(error);

      // Act & Assert
      await expect(sessionsController.expireToken(token)).rejects.toThrow(
        'Database error'
      );

      // Verify expireToken was called with the right argument
      expect(sessionsQueries.expireToken).toHaveBeenCalledWith(token);
    });
  });
});
