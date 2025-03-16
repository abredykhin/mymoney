/**
 * @file Unit tests for institutions queries
 */
// Import the module to test
const institutionsQueries = require('@/db/queries/institutions');

// Mock the database module
jest.mock('@/db', () => ({
  query: jest.fn(),
}));

// Mock the debug module
jest.mock('debug', () => () => jest.fn());

// Import the mocked modules
const db = require('@/db');

describe('Institutions Queries', () => {
  // Clear all mocks before each test
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createInstitution', () => {
    it('should create a new institution with provided details', async () => {
      // Arrange
      const institutionId = 'ins_123';
      const name = 'Test Bank';
      const primaryColor = '#00FF00';
      const url = 'https://testbank.com';
      const logo = 'https://testbank.com/logo.png';

      const mockInstitution = {
        id: 1,
        institution_id: institutionId,
        name: name,
        primary_color: primaryColor,
        url: url,
        logo: logo,
        updated_at: new Date(),
      };

      db.query.mockResolvedValueOnce({ rows: [mockInstitution] });

      // Act
      const result = await institutionsQueries.createInstitution(
        institutionId,
        name,
        primaryColor,
        url,
        logo
      );

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: expect.any(String),
        values: [institutionId, name, primaryColor, url, logo],
      });

      // Verify the SQL contains the key parts we care about
      expect(db.query.mock.calls[0][0].text).toContain(
        'INSERT INTO institutions_table'
      );
      expect(db.query.mock.calls[0][0].text).toContain(
        'ON CONFLICT(institution_id) DO UPDATE'
      );
      expect(result).toEqual(mockInstitution);
    });

    it('should handle errors when creating an institution', async () => {
      // Arrange
      const institutionId = 'ins_123';
      const name = 'Test Bank';
      const primaryColor = '#00FF00';
      const url = 'https://testbank.com';
      const logo = 'https://testbank.com/logo.png';

      const error = new Error('Database error');
      db.query.mockRejectedValueOnce(error);

      // Act & Assert
      await expect(
        institutionsQueries.createInstitution(
          institutionId,
          name,
          primaryColor,
          url,
          logo
        )
      ).rejects.toThrow('Database error');
    });
  });

  describe('retrieveInstitutionById', () => {
    it('should retrieve an institution by its ID', async () => {
      // Arrange
      const institutionId = 'ins_123';

      const mockInstitution = {
        id: 1,
        institution_id: institutionId,
        name: 'Test Bank',
        primary_color: '#00FF00',
        url: 'https://testbank.com',
        logo: 'https://testbank.com/logo.png',
        updated_at: new Date(),
      };

      db.query.mockResolvedValueOnce({ rows: [mockInstitution] });

      // Act
      const result =
        await institutionsQueries.retrieveInstitutionById(institutionId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM institutions WHERE institution_id = $1',
        values: [institutionId],
      });
      expect(result).toEqual(mockInstitution);
    });

    it('should return undefined when institution is not found', async () => {
      // Arrange
      const institutionId = 'nonexistent_institution';

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result =
        await institutionsQueries.retrieveInstitutionById(institutionId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM institutions WHERE institution_id = $1',
        values: [institutionId],
      });
      expect(result).toBeUndefined();
    });

    it('should handle errors when retrieving an institution', async () => {
      // Arrange
      const institutionId = 'ins_123';
      const error = new Error('Database error');

      db.query.mockRejectedValueOnce(error);

      // Act & Assert
      await expect(
        institutionsQueries.retrieveInstitutionById(institutionId)
      ).rejects.toThrow('Database error');
    });
  });
});
