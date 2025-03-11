/**
 * @file Unit tests for middleware functions
 */
const Boom = require('@hapi/boom');
const middleware = require('@/middleware');
const sessionQueries = require('@/db/queries/sessions');
const userQueries = require('@/db/queries/users');

// Mock the session and user queries
jest.mock('@/db/queries/sessions', () => ({
  lookupToken: jest.fn(),
}));

jest.mock('@/db/queries/users', () => ({
  retrieveUserById: jest.fn(),
}));

// // Mock debug
// jest.mock('debug', () => () => ({
//   extend: () => jest.fn(),
// }));

// Mock debug first, before requiring middleware
// Mock the debug module with a function that returns a function
jest.mock('debug', () => {
  // Create a mock debug function factory
  return jest.fn().mockImplementation(() => {
    // Create the debug function that can be called and has an extend method
    const debugFn = jest.fn();
    // Add extend method that returns another debug function
    debugFn.extend = jest.fn().mockImplementation(() => debugFn);
    return debugFn;
  });
});

describe('Middleware Functions', () => {
  // Mock Express req, res, next objects
  let req;
  let res;
  let next;

  beforeEach(() => {
    // Reset all mocks
    jest.clearAllMocks();

    // Mock Express request object
    req = {
      headers: {},
    };

    // Mock Express response object
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };

    // Mock Express next function
    next = jest.fn();
  });

  describe('asyncWrapper', () => {
    it('should call the wrapped function and pass req, res, next', async () => {
      // Arrange
      const mockFn = jest.fn().mockResolvedValue('result');
      const wrappedFn = middleware.asyncWrapper(mockFn);

      // Act
      await wrappedFn(req, res, next);

      // Assert
      expect(mockFn).toHaveBeenCalledWith(req, res, next);
    });

    it('should handle Boom errors by sending appropriate status and payload', async () => {
      // Arrange
      const boomError = Boom.badRequest('Bad Request');
      const mockFn = jest.fn().mockRejectedValue(boomError);
      const wrappedFn = middleware.asyncWrapper(mockFn);

      // Act
      await wrappedFn(req, res, next);

      // Assert
      expect(res.status).toHaveBeenCalledWith(400); // badRequest status code
      expect(res.json).toHaveBeenCalledWith(boomError.output.payload);
      expect(next).not.toHaveBeenCalled();
    });

    it('should handle non-Boom errors by sending 500 status', async () => {
      // Arrange
      const error = new Error('Standard error');
      const mockFn = jest.fn().mockRejectedValue(error);
      const wrappedFn = middleware.asyncWrapper(mockFn);

      // Act
      await wrappedFn(req, res, next);

      // Assert
      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          statusCode: 500,
          error: 'Internal Server Error',
        })
      );
      expect(next).not.toHaveBeenCalled();
    });
  });

  describe('errorHandler - Plaid Error handling', () => {
    it('should handle Plaid 400 errors using badRequest', () => {
      // Arrange
      const plaidError = {
        name: 'PlaidError',
        error_message: 'Bad Request Error',
        status_code: 400,
      };

      // Spy on Boom method
      const spy = jest.spyOn(Boom, 'badRequest');

      // Act
      middleware.errorHandler(plaidError, req, res, next);

      // Assert
      expect(spy).toHaveBeenCalledWith('Bad Request Error');
      expect(res.status).toHaveBeenCalledWith(400);

      // Clean up
      spy.mockRestore();
    });

    it('should handle Plaid 401 errors using unauthorized', () => {
      // Arrange
      const plaidError = {
        name: 'PlaidError',
        error_message: 'Unauthorized Error',
        status_code: 401,
      };

      // Spy on Boom method
      const spy = jest.spyOn(Boom, 'unauthorized');

      // Act
      middleware.errorHandler(plaidError, req, res, next);

      // Assert
      expect(spy).toHaveBeenCalledWith('Unauthorized Error');
      expect(res.status).toHaveBeenCalledWith(401);

      // Clean up
      spy.mockRestore();
    });

    it('should handle Plaid 403 errors using forbidden', () => {
      // Arrange
      const plaidError = {
        name: 'PlaidError',
        error_message: 'Forbidden Error',
        status_code: 403,
      };

      // Spy on Boom method
      const spy = jest.spyOn(Boom, 'forbidden');

      // Act
      middleware.errorHandler(plaidError, req, res, next);

      // Assert
      expect(spy).toHaveBeenCalledWith('Forbidden Error');
      expect(res.status).toHaveBeenCalledWith(403);

      // Clean up
      spy.mockRestore();
    });

    it('should handle Plaid 404 errors using notFound', () => {
      // Arrange
      const plaidError = {
        name: 'PlaidError',
        error_message: 'Not Found Error',
        status_code: 404,
      };

      // Spy on Boom method
      const spy = jest.spyOn(Boom, 'notFound');

      // Act
      middleware.errorHandler(plaidError, req, res, next);

      // Assert
      expect(spy).toHaveBeenCalledWith('Not Found Error');
      expect(res.status).toHaveBeenCalledWith(404);

      // Clean up
      spy.mockRestore();
    });

    it('should handle Plaid 409 errors using conflict', () => {
      // Arrange
      const plaidError = {
        name: 'PlaidError',
        error_message: 'Conflict Error',
        status_code: 409,
      };

      // Spy on Boom method
      const spy = jest.spyOn(Boom, 'conflict');

      // Act
      middleware.errorHandler(plaidError, req, res, next);

      // Assert
      expect(spy).toHaveBeenCalledWith('Conflict Error');
      expect(res.status).toHaveBeenCalledWith(409);

      // Clean up
      spy.mockRestore();
    });

    it('should handle Plaid 500+ errors using badImplementation', () => {
      // Arrange
      const plaidError = {
        name: 'PlaidError',
        error_message: 'Server Error',
        status_code: 500,
      };

      // Spy on Boom method
      const spy = jest.spyOn(Boom, 'badImplementation');

      // Act
      middleware.errorHandler(plaidError, req, res, next);

      // Assert
      expect(spy).toHaveBeenCalledWith('Server Error');
      expect(res.status).toHaveBeenCalledWith(500);

      // Clean up
      spy.mockRestore();
    });

    it('should handle other Plaid error codes using boomify', () => {
      // Arrange
      const plaidError = {
        name: 'PlaidError',
        error_message: 'Custom Error',
        status_code: 429, // Too Many Requests
      };

      // Spy on Boom method
      const spy = jest.spyOn(Boom, 'boomify');

      // Act
      middleware.errorHandler(plaidError, req, res, next);

      // Assert
      expect(spy).toHaveBeenCalledWith(expect.any(Error), { statusCode: 429 });
      expect(res.status).toHaveBeenCalledWith(429);

      // Clean up
      spy.mockRestore();
    });

    it('should boomify standard JS errors that are not already Boom errors', () => {
      // Arrange
      const standardError = new Error('Standard error');

      // Make sure the error is not a Boom error initially
      expect(standardError.isBoom).toBeUndefined();

      // Spy on Boom.boomify
      const boomifySpy = jest.spyOn(Boom, 'boomify');

      // Act
      middleware.errorHandler(standardError, req, res, next);

      // Assert
      expect(boomifySpy).toHaveBeenCalledWith(standardError);
      expect(res.status).toHaveBeenCalledWith(500); // Default status code for boomified errors
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          statusCode: 500,
          error: 'Internal Server Error',
        })
      );

      // Clean up
      boomifySpy.mockRestore();
    });
  });

  // These are the tests that need fixing - keep the rest of your test file the same
  describe('verifyToken', () => {
    it('should pass when token is valid and user exists', async () => {
      // Arrange
      req.headers.authorization = 'Bearer valid-token';
      sessionQueries.lookupToken.mockResolvedValue({ user_id: 1 });

      const mockUser = { id: 1, username: 'testuser' };
      userQueries.retrieveUserById.mockResolvedValue(mockUser);

      // Act
      await middleware.verifyToken(req, res, next);

      // Assert
      expect(sessionQueries.lookupToken).toHaveBeenCalledWith('valid-token');
      expect(userQueries.retrieveUserById).toHaveBeenCalledWith(1);
      expect(req.token).toBe('valid-token');
      expect(req.user).toEqual(mockUser);
      expect(req.userId).toBe(1);
      expect(next).toHaveBeenCalledWith();
    });

    it('should return 401 when authorization header is missing', async () => {
      // Arrange
      req.headers.authorization = undefined;

      // Act
      await middleware.verifyToken(req, res, next);

      // Assert
      expect(next).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Token not found!',
        })
      );
    });

    it('should return 401 when authorization header is malformed', async () => {
      // Arrange
      req.headers.authorization = 'malformed-header';

      // Act
      await middleware.verifyToken(req, res, next);

      // Assert
      expect(next).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Token not found!',
        })
      );
    });

    it('should return 401 when token is not found in database', async () => {
      // Arrange
      req.headers.authorization = 'Bearer invalid-token';
      sessionQueries.lookupToken.mockResolvedValue(null);

      // Act
      await middleware.verifyToken(req, res, next);

      // Assert
      expect(sessionQueries.lookupToken).toHaveBeenCalledWith('invalid-token');
      expect(next).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Token not found!',
        })
      );
    });

    it('should return 401 when user is not found', async () => {
      // Arrange
      req.headers.authorization = 'Bearer valid-token';
      sessionQueries.lookupToken.mockResolvedValue({ user_id: 999 });
      userQueries.retrieveUserById.mockResolvedValue(null);

      // Act
      await middleware.verifyToken(req, res, next);

      // Assert
      expect(sessionQueries.lookupToken).toHaveBeenCalledWith('valid-token');
      expect(userQueries.retrieveUserById).toHaveBeenCalledWith(999);
      expect(next).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Token not found!',
        })
      );
    });
  });
});
