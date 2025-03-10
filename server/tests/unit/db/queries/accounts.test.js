/**
 * @file Unit tests for accounts queries
 */
// Import the module to test
const accountsQueries = require('@/db/queries/accounts');

// Mock the items queries module that's imported by accounts
jest.mock('@/db/queries/items', () => ({
  retrieveItemByPlaidItemId: jest.fn(),
}));

// Mock the database module
jest.mock('@/db', () => ({
  query: jest.fn(),
}));

// Mock the debug module
jest.mock('debug', () => () => jest.fn());

// Import the mocked modules
const itemsQueries = require('@/db/queries/items');
const db = require('@/db');

describe('Accounts Queries', () => {
  // Clear all mocks before each test
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createAccounts', () => {
    it('should create multiple accounts related to a single item', async () => {
      // Arrange
      const plaidItemId = 'item-sandbox-123';
      const mockItemId = 42;
      const mockAccounts = [
        {
          account_id: 'account-sandbox-1',
          name: 'Checking Account',
          mask: '1234',
          official_name: 'Premium Checking',
          balances: {
            available: 1000.42,
            current: 1200.34,
            iso_currency_code: 'USD',
            unofficial_currency_code: null,
          },
          subtype: 'checking',
          type: 'depository',
        },
        {
          account_id: 'account-sandbox-2',
          name: 'Savings Account',
          mask: '5678',
          official_name: 'High Yield Savings',
          balances: {
            available: 5000.0,
            current: 5000.0,
            iso_currency_code: 'USD',
            unofficial_currency_code: null,
          },
          subtype: 'savings',
          type: 'depository',
        },
      ];

      const mockCreatedAccounts = [
        {
          id: 101,
          item_id: mockItemId,
          plaid_account_id: 'account-sandbox-1',
          name: 'Checking Account',
          mask: '1234',
          official_name: 'Premium Checking',
          current_balance: 1200.34,
          available_balance: 1000.42,
          iso_currency_code: 'USD',
          unofficial_currency_code: null,
          type: 'depository',
          subtype: 'checking',
          created_at: new Date(),
          updated_at: new Date(),
        },
        {
          id: 102,
          item_id: mockItemId,
          plaid_account_id: 'account-sandbox-2',
          name: 'Savings Account',
          mask: '5678',
          official_name: 'High Yield Savings',
          current_balance: 5000.0,
          available_balance: 5000.0,
          iso_currency_code: 'USD',
          unofficial_currency_code: null,
          type: 'depository',
          subtype: 'savings',
          created_at: new Date(),
          updated_at: new Date(),
        },
      ];

      // Mock the item query to return our test item ID
      itemsQueries.retrieveItemByPlaidItemId.mockResolvedValue({
        id: mockItemId,
      });

      // Mock the database query to return our created accounts
      // First call is for the first account, second call is for the second account
      db.query
        .mockResolvedValueOnce({ rows: [mockCreatedAccounts[0]] })
        .mockResolvedValueOnce({ rows: [mockCreatedAccounts[1]] });

      // Act
      const result = await accountsQueries.createAccounts(
        plaidItemId,
        mockAccounts
      );

      // Assert
      expect(itemsQueries.retrieveItemByPlaidItemId).toHaveBeenCalledWith(
        plaidItemId
      );

      // Verify first account query
      expect(db.query).toHaveBeenNthCalledWith(1, {
        text: expect.stringMatching(/INSERT INTO accounts_table/),
        values: [
          mockItemId,
          'account-sandbox-1',
          'Checking Account',
          '1234',
          'Premium Checking',
          1200.34,
          1000.42,
          'USD',
          null,
          'depository',
          'checking',
        ],
      });

      // Verify second account query
      expect(db.query).toHaveBeenNthCalledWith(2, {
        text: expect.stringMatching(/INSERT INTO accounts_table/),
        values: [
          mockItemId,
          'account-sandbox-2',
          'Savings Account',
          '5678',
          'High Yield Savings',
          5000.0,
          5000.0,
          'USD',
          null,
          'depository',
          'savings',
        ],
      });

      // Verify the overall result
      expect(result).toEqual(mockCreatedAccounts);
      expect(result.length).toBe(2);
    });

    it('should handle errors appropriately', async () => {
      // Arrange
      const plaidItemId = 'item-sandbox-error';
      const mockItemId = 42;
      const mockAccounts = [
        {
          account_id: 'account-sandbox-error',
          name: 'Error Account',
          mask: '9999',
          official_name: 'Problem Account',
          balances: {
            available: 0,
            current: 0,
            iso_currency_code: 'USD',
            unofficial_currency_code: null,
          },
          subtype: 'checking',
          type: 'depository',
        },
      ];

      // Mock the item query to return our test item ID
      itemsQueries.retrieveItemByPlaidItemId.mockResolvedValue({
        id: mockItemId,
      });

      // Mock the database query to throw an error
      const dbError = new Error('Database error when creating account');
      db.query.mockRejectedValue(dbError);

      // Act & Assert
      await expect(
        accountsQueries.createAccounts(plaidItemId, mockAccounts)
      ).rejects.toThrow('Database error when creating account');
    });
  });

  describe('retrieveAccountByPlaidAccountId', () => {
    it('should retrieve an account by its Plaid account ID', async () => {
      // Arrange
      const plaidAccountId = 'account-sandbox-123';
      const mockAccount = {
        id: 101,
        plaid_account_id: plaidAccountId,
        name: 'Checking Account',
        mask: '1234',
        item_id: 42,
        user_id: 5,
        current_balance: 1200.34,
        available_balance: 1000.42,
      };

      db.query.mockResolvedValueOnce({ rows: [mockAccount] });

      // Act
      const result =
        await accountsQueries.retrieveAccountByPlaidAccountId(plaidAccountId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM accounts WHERE plaid_account_id = $1',
        values: [plaidAccountId],
      });
      expect(result).toEqual(mockAccount);
    });

    it('should return undefined when account not found', async () => {
      // Arrange
      const plaidAccountId = 'nonexistent-account';

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result =
        await accountsQueries.retrieveAccountByPlaidAccountId(plaidAccountId);

      // Assert
      expect(result).toBeUndefined();
    });
  });

  describe('retrieveAccountsByItemId', () => {
    it('should retrieve all accounts for a given item ID', async () => {
      // Arrange
      const itemId = 42;
      const mockAccounts = [
        {
          id: 101,
          item_id: itemId,
          name: 'Checking Account',
        },
        {
          id: 102,
          item_id: itemId,
          name: 'Savings Account',
        },
      ];

      db.query.mockResolvedValueOnce({ rows: mockAccounts });

      // Act
      const result = await accountsQueries.retrieveAccountsByItemId(itemId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM accounts WHERE item_id = $1 ORDER BY id',
        values: [itemId],
      });
      expect(result).toEqual(mockAccounts);
    });

    it('should return an empty array when no accounts found', async () => {
      // Arrange
      const itemId = 999;

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await accountsQueries.retrieveAccountsByItemId(itemId);

      // Assert
      expect(result).toEqual([]);
    });
  });

  describe('retrieveAccountsByUserId', () => {
    it('should retrieve all accounts for a given user ID', async () => {
      // Arrange
      const userId = 5;
      const mockAccounts = [
        {
          id: 101,
          user_id: userId,
          name: 'Checking Account',
        },
        {
          id: 102,
          user_id: userId,
          name: 'Savings Account',
        },
      ];

      db.query.mockResolvedValueOnce({ rows: mockAccounts });

      // Act
      const result = await accountsQueries.retrieveAccountsByUserId(userId);

      // Assert
      expect(db.query).toHaveBeenCalledWith({
        text: 'SELECT * FROM accounts WHERE user_id = $1 ORDER BY id',
        values: [userId],
      });
      expect(result).toEqual(mockAccounts);
    });

    it('should return an empty array when no accounts found', async () => {
      // Arrange
      const userId = 999;

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await accountsQueries.retrieveAccountsByUserId(userId);

      // Assert
      expect(result).toEqual([]);
    });
  });
});
