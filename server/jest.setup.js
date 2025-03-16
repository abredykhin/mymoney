// Store all created logger instances in a map for tests to access
const mockLoggerInstances = {};

// Create mock methods that we can spy on
const createMockMethods = () => ({
  debug: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
});

// Mock the logger factory function
jest.mock('@/utils/logger', () => {
  return jest.fn().mockImplementation(namespace => {
    // Create a new instance if one doesn't exist for this namespace
    if (!mockLoggerInstances[namespace]) {
      mockLoggerInstances[namespace] = createMockMethods();
    }
    // Return the existing instance for this namespace
    return mockLoggerInstances[namespace];
  });
});

// Expose the mockLoggerInstances so tests can access them
global.mockLoggerInstances = mockLoggerInstances;
