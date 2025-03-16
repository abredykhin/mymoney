/**
 * @file Unit tests for items queries
 */
// Import the module to test
const itemsQueries = require('@/db/queries/items');

// Mock the database module
jest.mock('@/db', () => ({
  query: jest.fn(),
}));

// Mock the debug module
jest.mock('debug', () => () => jest.fn());

// Suppress console.log output in tests
jest.spyOn(console, 'log').mockImplementation(() => {});

// Import the mocked modules
const db = require('@/db');

describe('Items Queries', () => {
  // Clear all mocks before each test
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createItem', () => {
    it('should create a new item with provided details', async () => {
      // Arrange
      const plaidInstitutionId = 'ins_123';
      const plaidAccessToken = 'access-sandbox-123';
      const plaidItemId = 'item_123';
      const userId = 42;
      const bankName = 'Test Bank';

      const mockItem = {
        id: 1,
        user_id: userId,
        plaid_access_token: plaidAccessToken,
        plaid_item_id: plaidItemId,
        plaid_institution_id: plaidInstitutionId,
        status: 'good',
        bank_name: bankName,
        created_at: new Date(),
        updated_at: new Date(),
        transactions_cursor: null,
        is_active: true,
      };

      db.query.mockResolvedValueOnce({ rows: [mockItem] });

      // Act
      const result = await itemsQueries.createItem(
        plaidInstitutionId,
        plaidAccessToken,
        plaidItemId,
        userId,
        bankName
      );

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: expect.any(String),
        values: [
          userId,
          plaidAccessToken,
          plaidItemId,
          plaidInstitutionId,
          'good',
          bankName,
        ],
      });

      // Verify the SQL contains the key parts we care about
      expect(db.query.mock.calls[0][0].text).toContain(
        'INSERT INTO items_table'
      );
      expect(db.query.mock.calls[0][0].text).toContain(
        'ON CONFLICT (plaid_item_id) DO UPDATE'
      );
      expect(result).toEqual(mockItem);
    });

    it('should handle errors when creating an item', async () => {
      // Arrange
      const plaidInstitutionId = 'ins_123';
      const plaidAccessToken = 'access-sandbox-123';
      const plaidItemId = 'item_123';
      const userId = 42;
      const bankName = 'Test Bank';

      const error = new Error('Database error');
      db.query.mockRejectedValueOnce(error);

      // Act & Assert
      await expect(
        itemsQueries.createItem(
          plaidInstitutionId,
          plaidAccessToken,
          plaidItemId,
          userId,
          bankName
        )
      ).rejects.toThrow('Database error');
    });
  });

  describe('retrieveItemById', () => {
    it('should retrieve an item by its ID', async () => {
      // Arrange
      const itemId = 1;

      const mockItem = {
        id: itemId,
        user_id: 42,
        plaid_access_token: 'access-sandbox-123',
        plaid_item_id: 'item_123',
        plaid_institution_id: 'ins_123',
        status: 'good',
        bank_name: 'Test Bank',
        created_at: new Date(),
        updated_at: new Date(),
        transactions_cursor: null,
        is_active: true,
      };

      db.query.mockResolvedValueOnce({ rows: [mockItem] });

      // Act
      const result = await itemsQueries.retrieveItemById(itemId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM items WHERE id = $1',
        values: [itemId],
      });
      expect(result).toEqual(mockItem);
    });

    it('should return undefined when item is not found by ID', async () => {
      // Arrange
      const itemId = 999;

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await itemsQueries.retrieveItemById(itemId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM items WHERE id = $1',
        values: [itemId],
      });
      expect(result).toBeUndefined();
    });
  });

  describe('retrieveItemByPlaidAccessToken', () => {
    it('should retrieve an item by its Plaid access token', async () => {
      // Arrange
      const accessToken = 'access-sandbox-123';

      const mockItem = {
        id: 1,
        user_id: 42,
        plaid_access_token: accessToken,
        plaid_item_id: 'item_123',
        plaid_institution_id: 'ins_123',
        status: 'good',
        bank_name: 'Test Bank',
      };

      db.query.mockResolvedValueOnce({ rows: [mockItem] });

      // Act
      const result =
        await itemsQueries.retrieveItemByPlaidAccessToken(accessToken);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM items WHERE plaid_access_token = $1',
        values: [accessToken],
      });
      expect(result).toEqual(mockItem);
    });

    it('should return undefined when item is not found by access token', async () => {
      // Arrange
      const accessToken = 'nonexistent-token';

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result =
        await itemsQueries.retrieveItemByPlaidAccessToken(accessToken);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM items WHERE plaid_access_token = $1',
        values: [accessToken],
      });
      expect(result).toBeUndefined();
    });
  });

  describe('retrieveItemByPlaidInstitutionId', () => {
    it('should retrieve an item by its Plaid institution ID and user ID', async () => {
      // Arrange
      const plaidInstitutionId = 'ins_123';
      const userId = 42;

      const mockItem = {
        id: 1,
        user_id: userId,
        plaid_access_token: 'access-sandbox-123',
        plaid_item_id: 'item_123',
        plaid_institution_id: plaidInstitutionId,
        status: 'good',
        bank_name: 'Test Bank',
      };

      db.query.mockResolvedValueOnce({ rows: [mockItem] });

      // Act
      const result = await itemsQueries.retrieveItemByPlaidInstitutionId(
        plaidInstitutionId,
        userId
      );

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM items WHERE plaid_institution_id = $1 AND user_id = $2',
        values: [plaidInstitutionId, userId],
      });
      expect(result).toEqual(mockItem);
    });

    it('should return undefined when item is not found by institution ID and user ID', async () => {
      // Arrange
      const plaidInstitutionId = 'nonexistent-institution';
      const userId = 42;

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await itemsQueries.retrieveItemByPlaidInstitutionId(
        plaidInstitutionId,
        userId
      );

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM items WHERE plaid_institution_id = $1 AND user_id = $2',
        values: [plaidInstitutionId, userId],
      });
      expect(result).toBeUndefined();
    });
  });

  describe('retrieveItemByPlaidItemId', () => {
    it('should retrieve an item by its Plaid item ID', async () => {
      // Arrange
      const plaidItemId = 'item_123';

      const mockItem = {
        id: 1,
        user_id: 42,
        plaid_access_token: 'access-sandbox-123',
        plaid_item_id: plaidItemId,
        plaid_institution_id: 'ins_123',
        status: 'good',
        bank_name: 'Test Bank',
      };

      db.query.mockResolvedValueOnce({ rows: [mockItem] });

      // Act
      const result = await itemsQueries.retrieveItemByPlaidItemId(plaidItemId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM items WHERE plaid_item_id = $1',
        values: [plaidItemId],
      });
      expect(result).toEqual(mockItem);
    });

    it('should return undefined when item is not found by Plaid item ID', async () => {
      // Arrange
      const plaidItemId = 'nonexistent-item';

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await itemsQueries.retrieveItemByPlaidItemId(plaidItemId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM items WHERE plaid_item_id = $1',
        values: [plaidItemId],
      });
      expect(result).toBeUndefined();
    });
  });

  describe('retrieveItemsByUser', () => {
    it('should retrieve all items for a user', async () => {
      // Arrange
      const userId = 42;

      const mockItems = [
        {
          id: 1,
          user_id: userId,
          plaid_access_token: 'access-sandbox-123',
          plaid_item_id: 'item_123',
          plaid_institution_id: 'ins_123',
          status: 'good',
          bank_name: 'Test Bank',
        },
        {
          id: 2,
          user_id: userId,
          plaid_access_token: 'access-sandbox-456',
          plaid_item_id: 'item_456',
          plaid_institution_id: 'ins_456',
          status: 'good',
          bank_name: 'Another Bank',
        },
      ];

      db.query.mockResolvedValueOnce({ rows: mockItems });

      // Act
      const result = await itemsQueries.retrieveItemsByUser(userId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM items WHERE user_id = $1',
        values: [userId],
      });
      expect(result).toEqual(mockItems);
    });

    it('should return an empty array when user has no items', async () => {
      // Arrange
      const userId = 999;

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await itemsQueries.retrieveItemsByUser(userId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM items WHERE user_id = $1',
        values: [userId],
      });
      expect(result).toEqual([]);
    });
  });

  describe('updateItemStatus', () => {
    it('should update the status of an item', async () => {
      // Arrange
      const plaidItemId = 'item_123';
      const status = 'bad';

      db.query.mockResolvedValueOnce({ rowCount: 1 });

      // Act
      await itemsQueries.updateItemStatus(plaidItemId, status);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'UPDATE items_table SET status = $1 WHERE plaid_item_id = $2',
        values: [status, plaidItemId],
      });
    });

    it('should handle errors when updating item status', async () => {
      // Arrange
      const plaidItemId = 'item_123';
      const status = 'bad';

      const error = new Error('Database error');
      db.query.mockRejectedValueOnce(error);

      // Act & Assert
      await expect(
        itemsQueries.updateItemStatus(plaidItemId, status)
      ).rejects.toThrow('Database error');
    });
  });

  describe('updateItemTransactionsCursor', () => {
    it('should update the transactions cursor of an item', async () => {
      // Arrange
      const plaidItemId = 'item_123';
      const transactionsCursor = 'cursor-value-123';

      db.query.mockResolvedValueOnce({ rowCount: 1 });

      // Act
      await itemsQueries.updateItemTransactionsCursor(
        plaidItemId,
        transactionsCursor
      );

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'UPDATE items_table SET transactions_cursor = $1 WHERE plaid_item_id = $2',
        values: [transactionsCursor, plaidItemId],
      });
    });

    it('should handle errors when updating transactions cursor', async () => {
      // Arrange
      const plaidItemId = 'item_123';
      const transactionsCursor = 'cursor-value-123';

      const error = new Error('Database error');
      db.query.mockRejectedValueOnce(error);

      // Act & Assert
      await expect(
        itemsQueries.updateItemTransactionsCursor(
          plaidItemId,
          transactionsCursor
        )
      ).rejects.toThrow('Database error');
    });
  });

  describe('deleteItem', () => {
    it('should delete an item by its ID', async () => {
      // Arrange
      const itemId = 1;

      db.query.mockResolvedValueOnce({ rowCount: 1 });

      // Act
      await itemsQueries.deleteItem(itemId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'DELETE FROM items_table WHERE id = $1',
        values: [itemId],
      });
    });

    it('should handle errors when deleting an item', async () => {
      // Arrange
      const itemId = 1;

      const error = new Error('Database error');
      db.query.mockRejectedValueOnce(error);

      // Act & Assert
      await expect(itemsQueries.deleteItem(itemId)).rejects.toThrow(
        'Database error'
      );
    });
  });
});
