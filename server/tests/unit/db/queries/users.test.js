/**
 * @file Unit tests for user queries
 */
const userQueries = require('@/db/queries/users');

// Mock the database module with cleaner path
jest.mock('@/db', () => ({
  query: jest.fn(),
}));

// Mock the debug module
jest.mock('debug', () => () => jest.fn());

// Import the mocked db module
const db = require('@/db');

describe('User Queries', () => {
  // Clear all mocks before each test
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createUser', () => {
    it('should create a new user with username and hashed password', async () => {
      // Arrange
      const username = 'testuser';
      const hashedPassword = 'hashedpassword123';
      const mockUser = {
        id: 1,
        username,
        password: hashedPassword,
        created_at: new Date(),
        updated_at: new Date(),
      };

      db.query.mockResolvedValueOnce({ rows: [mockUser] });

      // Act
      const result = await userQueries.createUser(username, hashedPassword);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'INSERT INTO users_table (username, password) VALUES ($1, $2) RETURNING *;',
        values: [username, hashedPassword],
      });
      expect(result).toEqual(mockUser);
    });

    it('should throw an error if database query fails', async () => {
      // Arrange
      const username = 'testuser';
      const hashedPassword = 'hashedpassword123';
      const error = new Error('Database error');

      db.query.mockRejectedValueOnce(error);

      // Act & Assert
      await expect(
        userQueries.createUser(username, hashedPassword)
      ).rejects.toThrow('Database error');
    });
  });

  describe('deleteUsers', () => {
    it('should delete a user by ID', async () => {
      // Arrange
      const userId = 1;
      db.query.mockResolvedValueOnce({ rowCount: 1 });

      // Act
      await userQueries.deleteUsers(userId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'DELETE FROM users_table WHERE id = $1;',
        values: [userId],
      });
    });
  });

  describe('retrieveUserById', () => {
    it('should retrieve a user by ID', async () => {
      // Arrange
      const userId = 1;
      const mockUser = {
        id: userId,
        username: 'testuser',
        created_at: new Date(),
        updated_at: new Date(),
      };

      db.query.mockResolvedValueOnce({ rows: [mockUser] });

      // Act
      const result = await userQueries.retrieveUserById(userId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM users WHERE id = $1',
        values: [userId],
      });
      expect(result).toEqual(mockUser);
    });

    it('should return undefined if user is not found', async () => {
      // Arrange
      const userId = 999;
      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await userQueries.retrieveUserById(userId);

      // Assert
      expect(result).toBeUndefined();
    });
  });

  describe('retrieveUserByUsername', () => {
    it('should retrieve a user by username', async () => {
      // Arrange
      const username = 'testuser';
      const mockUser = {
        id: 1,
        username,
        created_at: new Date(),
        updated_at: new Date(),
      };

      db.query.mockResolvedValueOnce({ rows: [mockUser] });

      // Act
      const result = await userQueries.retrieveUserByUsername(username);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM users WHERE username = $1',
        values: [username],
      });
      expect(result).toEqual(mockUser);
    });

    it('should return undefined if username is not found', async () => {
      // Arrange
      const username = 'nonexistentuser';
      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await userQueries.retrieveUserByUsername(username);

      // Assert
      expect(result).toBeUndefined();
    });
  });

  describe('retrieveUsers', () => {
    it('should retrieve all users', async () => {
      // Arrange
      const mockUsers = [
        { id: 1, username: 'user1' },
        { id: 2, username: 'user2' },
      ];

      db.query.mockResolvedValueOnce({ rows: mockUsers });

      // Act
      const result = await userQueries.retrieveUsers();

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM users',
      });
      expect(result).toEqual(mockUsers);
    });

    it('should return an empty array if no users exist', async () => {
      // Arrange
      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await userQueries.retrieveUsers();

      // Assert
      expect(result).toEqual([]);
    });
  });

  describe('updateUserPassword', () => {
    it("should update a user's password", async () => {
      // Arrange
      const userId = 1;
      const newPassword = 'newhashedpassword456';
      const mockUser = {
        id: userId,
        username: 'testuser',
        password: newPassword,
        created_at: new Date(),
        updated_at: new Date(),
      };

      db.query.mockResolvedValueOnce({ rows: [mockUser] });

      // Act
      const result = await userQueries.updateUserPassword(userId, newPassword);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'UPDATE users SET password = $1 WHERE id = $2 RETURNING *',
        values: [newPassword, userId],
      });
      expect(result).toEqual(mockUser);
    });

    it('should return undefined if user ID is not found', async () => {
      // Arrange
      const userId = 999;
      const newPassword = 'newhashedpassword456';
      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await userQueries.updateUserPassword(userId, newPassword);

      // Assert
      expect(result).toBeUndefined();
    });
  });
});
