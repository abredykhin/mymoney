/**
 * @file Unit tests for users controller
 */

// Mock dependencies before importing controller
jest.mock('bcrypt', () => ({
  genSalt: jest.fn().mockResolvedValue('mock-salt'),
  hash: jest.fn().mockResolvedValue('hashed-password'),
  compare: jest.fn(),
}));

jest.mock('@/db/queries/users', () => ({
  retrieveUserByUsername: jest.fn(),
  createUser: jest.fn(),
  updateUserPassword: jest.fn(),
}));

jest.mock('debug', () => () => jest.fn());

// Import the module and mocked dependencies
const usersController = require('@/controllers/users');
const bcrypt = require('bcrypt');
const usersQueries = require('@/db/queries/users');
const Boom = require('@hapi/boom');

describe('Users Controller', () => {
  let req;

  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();

    // Reset the request object
    req = {
      body: {},
    };
  });

  describe('registerUser', () => {
    it('should register a new user with valid inputs', async () => {
      // Arrange
      req.body = { username: 'newuser', password: 'password123' };

      const mockUser = {
        id: 1,
        username: 'newuser',
        created_at: new Date(),
        updated_at: new Date(),
      };

      // User doesn't exist yet
      usersQueries.retrieveUserByUsername.mockResolvedValue(null);

      // User creation is successful
      usersQueries.createUser.mockResolvedValue(mockUser);

      // Act
      const result = await usersController.registerUser(req);

      // Assert
      expect(usersQueries.retrieveUserByUsername).toHaveBeenCalledWith(
        'newuser'
      );
      expect(bcrypt.genSalt).toHaveBeenCalledWith(10);
      expect(bcrypt.hash).toHaveBeenCalledWith('password123', 'mock-salt');
      expect(usersQueries.createUser).toHaveBeenCalledWith(
        'newuser',
        'hashed-password'
      );
      expect(result).toEqual(mockUser);
    });

    it('should throw badRequest when username or password is missing', async () => {
      // Arrange
      req.body = { username: 'newuser' }; // Missing password

      // Act & Assert
      await expect(usersController.registerUser(req)).rejects.toEqual(
        expect.objectContaining({
          isBoom: true,
          output: expect.objectContaining({
            statusCode: 400,
          }),
        })
      );

      expect(usersQueries.retrieveUserByUsername).not.toHaveBeenCalled();
      expect(bcrypt.genSalt).not.toHaveBeenCalled();
    });

    it('should throw conflict when user already exists', async () => {
      // Arrange
      req.body = { username: 'existinguser', password: 'password123' };

      // User already exists
      usersQueries.retrieveUserByUsername.mockResolvedValue({
        id: 1,
        username: 'existinguser',
      });

      // Act & Assert
      await expect(usersController.registerUser(req)).rejects.toEqual(
        expect.objectContaining({
          isBoom: true,
          output: expect.objectContaining({
            statusCode: 409,
          }),
        })
      );

      expect(usersQueries.createUser).not.toHaveBeenCalled();
    });

    it('should propagate database errors during user creation', async () => {
      // Arrange
      req.body = { username: 'newuser', password: 'password123' };

      // User doesn't exist
      usersQueries.retrieveUserByUsername.mockResolvedValue(null);

      // Database error during user creation
      const dbError = new Error('Database error');
      usersQueries.createUser.mockRejectedValue(dbError);

      // Act & Assert
      await expect(usersController.registerUser(req)).rejects.toThrow(
        'Database error'
      );
    });
  });

  describe('loginUser', () => {
    it('should login a user with valid credentials', async () => {
      // Arrange
      req.body = { username: 'existinguser', password: 'correct-password' };

      const mockUser = {
        id: 1,
        username: 'existinguser',
        password: 'hashed-password',
      };

      // User exists
      usersQueries.retrieveUserByUsername.mockResolvedValue(mockUser);

      // Password is correct
      bcrypt.compare.mockResolvedValue(true);

      // Act
      const result = await usersController.loginUser(req);

      // Assert
      expect(usersQueries.retrieveUserByUsername).toHaveBeenCalledWith(
        'existinguser'
      );
      expect(bcrypt.compare).toHaveBeenCalledWith(
        'correct-password',
        'hashed-password'
      );
      expect(result).toEqual(mockUser);
    });

    it('should throw badRequest when username or password is missing', async () => {
      // Arrange
      req.body = { username: 'existinguser' }; // Missing password

      // Act & Assert
      await expect(usersController.loginUser(req)).rejects.toEqual(
        expect.objectContaining({
          isBoom: true,
          output: expect.objectContaining({
            statusCode: 400,
          }),
        })
      );

      expect(usersQueries.retrieveUserByUsername).not.toHaveBeenCalled();
    });

    it('should throw unauthorized when user does not exist', async () => {
      // Arrange
      req.body = { username: 'nonexistentuser', password: 'password123' };

      // User does not exist
      usersQueries.retrieveUserByUsername.mockResolvedValue(null);

      // Act & Assert
      await expect(usersController.loginUser(req)).rejects.toEqual(
        expect.objectContaining({
          isBoom: true,
          output: expect.objectContaining({
            statusCode: 401,
          }),
        })
      );

      expect(bcrypt.compare).not.toHaveBeenCalled();
    });

    it('should throw unauthorized when password is incorrect', async () => {
      // Arrange
      req.body = { username: 'existinguser', password: 'wrong-password' };

      const mockUser = {
        id: 1,
        username: 'existinguser',
        password: 'hashed-password',
      };

      // User exists
      usersQueries.retrieveUserByUsername.mockResolvedValue(mockUser);

      // Password is incorrect
      bcrypt.compare.mockResolvedValue(false);

      // Act & Assert
      await expect(usersController.loginUser(req)).rejects.toEqual(
        expect.objectContaining({
          isBoom: true,
          output: expect.objectContaining({
            statusCode: 401,
          }),
        })
      );
    });
  });

  describe('debugChangePassword', () => {
    it('should change password for an existing user', async () => {
      // Arrange
      req.body = { username: 'existinguser', newPassword: 'new-password123' };

      const mockUser = {
        id: 1,
        username: 'existinguser',
      };

      const mockUpdatedUser = {
        ...mockUser,
        updated_at: new Date(),
      };

      // User exists
      usersQueries.retrieveUserByUsername.mockResolvedValue(mockUser);

      // Password update is successful
      usersQueries.updateUserPassword.mockResolvedValue(mockUpdatedUser);

      // Act
      const result = await usersController.debugChangePassword(req);

      // Assert
      expect(usersQueries.retrieveUserByUsername).toHaveBeenCalledWith(
        'existinguser'
      );
      expect(bcrypt.genSalt).toHaveBeenCalledWith(10);
      expect(bcrypt.hash).toHaveBeenCalledWith('new-password123', 'mock-salt');
      expect(usersQueries.updateUserPassword).toHaveBeenCalledWith(
        1,
        'hashed-password'
      );
      expect(result).toEqual(mockUpdatedUser);
    });

    it('should throw badRequest when username or newPassword is missing', async () => {
      // Arrange
      req.body = { username: 'existinguser' }; // Missing newPassword

      // Act & Assert
      await expect(usersController.debugChangePassword(req)).rejects.toEqual(
        expect.objectContaining({
          isBoom: true,
          output: expect.objectContaining({
            statusCode: 400,
          }),
        })
      );

      expect(usersQueries.retrieveUserByUsername).not.toHaveBeenCalled();
    });

    it('should throw unauthorized when user does not exist', async () => {
      // Arrange
      req.body = {
        username: 'nonexistentuser',
        newPassword: 'new-password123',
      };

      // User does not exist
      usersQueries.retrieveUserByUsername.mockResolvedValue(null);

      // Act & Assert
      await expect(usersController.debugChangePassword(req)).rejects.toEqual(
        expect.objectContaining({
          isBoom: true,
          output: expect.objectContaining({
            statusCode: 401,
          }),
        })
      );

      expect(bcrypt.genSalt).not.toHaveBeenCalled();
      expect(usersQueries.updateUserPassword).not.toHaveBeenCalled();
    });

    it('should propagate database errors during password update', async () => {
      // Arrange
      req.body = { username: 'existinguser', newPassword: 'new-password123' };

      const mockUser = {
        id: 1,
        username: 'existinguser',
      };

      // User exists
      usersQueries.retrieveUserByUsername.mockResolvedValue(mockUser);

      // Database error during password update
      const dbError = new Error('Database error');
      usersQueries.updateUserPassword.mockRejectedValue(dbError);

      // Act & Assert
      await expect(usersController.debugChangePassword(req)).rejects.toThrow(
        'Database error'
      );

      expect(bcrypt.genSalt).toHaveBeenCalled();
      expect(bcrypt.hash).toHaveBeenCalled();
    });
  });
});
