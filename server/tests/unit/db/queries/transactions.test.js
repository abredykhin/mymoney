/**
 * @file Unit tests for transactions queries - Batch Insert Optimization
 */

// Mock the accounts queries module
jest.mock('@/db/queries/accounts', () => ({
  retrieveAccountByPlaidAccountId: jest.fn(),
}));

// Mock the database module
jest.mock('@/db', () => ({
  query: jest.fn(),
  connect: jest.fn(),
}));

// Mock the debug module
jest.mock('debug', () => () => jest.fn());

// Mock the logger
jest.mock('@/utils/logger', () => ({
  error: jest.fn(),
}));

// Import the modules
const transactionsQueries = require('@/db/queries/transactions');
const db = require('@/db');
const logger = require('@/utils/logger');

describe('Transactions Queries - Batch Insert Optimization', () => {
  let mockClient;

  beforeEach(() => {
    jest.clearAllMocks();

    // Mock database client with transaction support
    mockClient = {
      query: jest.fn(),
      release: jest.fn(),
    };

    db.connect.mockResolvedValue(mockClient);
  });

  describe('createOrUpdateTransactions - Batch Operations', () => {
    it('should handle empty transactions array', async () => {
      // Act
      const result = await transactionsQueries.createOrUpdateTransactions([]);

      // Assert
      expect(result).toEqual({ success: true });
      expect(db.connect).not.toHaveBeenCalled();
    });

    it('should successfully insert single transaction using batch method', async () => {
      // Arrange
      const mockTransactions = [
        {
          account_id: 'plaid-account-1',
          amount: 100.50,
          iso_currency_code: 'USD',
          date: '2025-12-10',
          authorized_date: '2025-12-09',
          name: 'Coffee Shop',
          merchant_name: 'Starbucks',
          logo_url: 'https://logo.url',
          website: 'https://starbucks.com',
          payment_channel: 'in store',
          transaction_id: 'txn-123',
          personal_finance_category: {
            primary: 'FOOD_AND_DRINK',
            detailed: 'FOOD_AND_DRINK_COFFEE',
          },
          pending: false,
          pending_transaction_id: null,
        },
      ];

      const mockAccounts = [
        { id: 101, plaid_account_id: 'plaid-account-1' },
      ];

      // Mock BEGIN
      mockClient.query.mockResolvedValueOnce({ rows: [] });

      // Mock account lookup query
      mockClient.query.mockResolvedValueOnce({ rows: mockAccounts });

      // Mock batch INSERT
      mockClient.query.mockResolvedValueOnce({ rows: [] });

      // Mock COMMIT
      mockClient.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const result = await transactionsQueries.createOrUpdateTransactions(mockTransactions);

      // Assert
      expect(result).toEqual({ success: true });
      expect(mockClient.query).toHaveBeenCalledTimes(4); // BEGIN, SELECT, INSERT, COMMIT

      // Verify BEGIN was called
      expect(mockClient.query).toHaveBeenNthCalledWith(1, 'BEGIN');

      // Verify batch account lookup
      expect(mockClient.query).toHaveBeenNthCalledWith(2, {
        text: expect.stringContaining('plaid_account_id = ANY'),
        values: [['plaid-account-1']],
      });

      // Verify batch INSERT with correct structure
      expect(mockClient.query).toHaveBeenNthCalledWith(3, {
        text: expect.stringContaining('INSERT INTO transactions_table'),
        values: [
          101, // account_id (mapped)
          100.50,
          'USD',
          '2025-12-10',
          '2025-12-09',
          'Coffee Shop',
          'Starbucks',
          'https://logo.url',
          'https://starbucks.com',
          'in store',
          'txn-123',
          'FOOD_AND_DRINK',
          'FOOD_AND_DRINK_COFFEE',
          false,
          null,
        ],
      });

      // Verify COMMIT
      expect(mockClient.query).toHaveBeenNthCalledWith(4, 'COMMIT');
      expect(mockClient.release).toHaveBeenCalled();
    });

    it('should batch insert 3 transactions in single query', async () => {
      // Arrange
      const mockTransactions = [
        {
          account_id: 'plaid-account-1',
          amount: 50.00,
          iso_currency_code: 'USD',
          date: '2025-12-10',
          authorized_date: null,
          name: 'Transaction 1',
          merchant_name: null,
          logo_url: null,
          website: null,
          payment_channel: 'online',
          transaction_id: 'txn-1',
          personal_finance_category: null,
          pending: false,
          pending_transaction_id: null,
        },
        {
          account_id: 'plaid-account-2',
          amount: 75.25,
          iso_currency_code: 'USD',
          date: '2025-12-11',
          authorized_date: null,
          name: 'Transaction 2',
          merchant_name: null,
          logo_url: null,
          website: null,
          payment_channel: 'online',
          transaction_id: 'txn-2',
          personal_finance_category: null,
          pending: false,
          pending_transaction_id: null,
        },
        {
          account_id: 'plaid-account-1',
          amount: 100.00,
          iso_currency_code: 'USD',
          date: '2025-12-12',
          authorized_date: null,
          name: 'Transaction 3',
          merchant_name: null,
          logo_url: null,
          website: null,
          payment_channel: 'online',
          transaction_id: 'txn-3',
          personal_finance_category: null,
          pending: true,
          pending_transaction_id: null,
        },
      ];

      const mockAccounts = [
        { id: 101, plaid_account_id: 'plaid-account-1' },
        { id: 102, plaid_account_id: 'plaid-account-2' },
      ];

      // Mock queries
      mockClient.query
        .mockResolvedValueOnce({ rows: [] }) // BEGIN
        .mockResolvedValueOnce({ rows: mockAccounts }) // Account lookup
        .mockResolvedValueOnce({ rows: [] }) // Batch INSERT
        .mockResolvedValueOnce({ rows: [] }); // COMMIT

      // Act
      const result = await transactionsQueries.createOrUpdateTransactions(mockTransactions);

      // Assert
      expect(result).toEqual({ success: true });

      // Verify only 2 unique account IDs were queried
      expect(mockClient.query).toHaveBeenNthCalledWith(2, {
        text: expect.stringContaining('plaid_account_id = ANY'),
        values: [['plaid-account-1', 'plaid-account-2']],
      });

      // Verify batch INSERT has all 3 transactions (45 values: 3 × 15)
      const insertCall = mockClient.query.mock.calls[2][0];
      expect(insertCall.values.length).toBe(45); // 3 transactions × 15 fields

      // Verify VALUES clause has 3 rows
      expect(insertCall.text).toMatch(/VALUES\s+\(\$1[^)]+\),\s*\(\$16[^)]+\),\s*\(\$31[^)]+\)/s);
    });

    it('should handle transactions with missing account IDs gracefully', async () => {
      // Arrange
      const mockTransactions = [
        {
          account_id: 'plaid-account-1',
          amount: 50.00,
          iso_currency_code: 'USD',
          date: '2025-12-10',
          name: 'Valid Transaction',
          transaction_id: 'txn-valid',
          payment_channel: 'online',
          pending: false,
        },
        {
          account_id: 'plaid-account-missing', // This account doesn't exist
          amount: 75.00,
          iso_currency_code: 'USD',
          date: '2025-12-11',
          name: 'Invalid Transaction',
          transaction_id: 'txn-invalid',
          payment_channel: 'online',
          pending: false,
        },
      ];

      const mockAccounts = [
        { id: 101, plaid_account_id: 'plaid-account-1' },
        // plaid-account-missing is NOT in the results
      ];

      // Mock queries
      mockClient.query
        .mockResolvedValueOnce({ rows: [] }) // BEGIN
        .mockResolvedValueOnce({ rows: mockAccounts }) // Account lookup
        .mockResolvedValueOnce({ rows: [] }) // Batch INSERT (only 1 transaction)
        .mockResolvedValueOnce({ rows: [] }); // COMMIT

      // Act
      const result = await transactionsQueries.createOrUpdateTransactions(mockTransactions);

      // Assert
      expect(result).toEqual({ success: true });

      // Verify only 1 transaction was inserted (the valid one)
      const insertCall = mockClient.query.mock.calls[2][0];
      expect(insertCall.values.length).toBe(15); // Only 1 transaction × 15 fields
      expect(insertCall.values[10]).toBe('txn-valid'); // transaction_id is at index 10
    });

    it('should handle ON CONFLICT correctly for duplicate transactions', async () => {
      // Arrange
      const mockTransactions = [
        {
          account_id: 'plaid-account-1',
          amount: 50.00,
          iso_currency_code: 'USD',
          date: '2025-12-10',
          name: 'Updated Transaction',
          merchant_name: 'New Merchant',
          transaction_id: 'txn-duplicate',
          payment_channel: 'online',
          pending: false,
        },
      ];

      const mockAccounts = [
        { id: 101, plaid_account_id: 'plaid-account-1' },
      ];

      mockClient.query
        .mockResolvedValueOnce({ rows: [] }) // BEGIN
        .mockResolvedValueOnce({ rows: mockAccounts }) // Account lookup
        .mockResolvedValueOnce({ rows: [] }) // Batch INSERT with ON CONFLICT
        .mockResolvedValueOnce({ rows: [] }); // COMMIT

      // Act
      const result = await transactionsQueries.createOrUpdateTransactions(mockTransactions);

      // Assert
      expect(result).toEqual({ success: true });

      // Verify ON CONFLICT clause exists
      const insertCall = mockClient.query.mock.calls[2][0];
      expect(insertCall.text).toContain('ON CONFLICT (transaction_id) DO UPDATE');
      expect(insertCall.text).toContain('amount = EXCLUDED.amount');
      expect(insertCall.text).toContain('merchant_name = EXCLUDED.merchant_name');
    });

    it('should rollback on database error', async () => {
      // Arrange
      const mockTransactions = [
        {
          account_id: 'plaid-account-1',
          amount: 50.00,
          iso_currency_code: 'USD',
          date: '2025-12-10',
          name: 'Transaction',
          transaction_id: 'txn-error',
          payment_channel: 'online',
          pending: false,
        },
      ];

      const mockAccounts = [
        { id: 101, plaid_account_id: 'plaid-account-1' },
      ];

      const dbError = new Error('Database constraint violation');

      mockClient.query
        .mockResolvedValueOnce({ rows: [] }) // BEGIN
        .mockResolvedValueOnce({ rows: mockAccounts }) // Account lookup
        .mockRejectedValueOnce(dbError) // Batch INSERT fails
        .mockResolvedValueOnce({ rows: [] }); // ROLLBACK

      // Act
      const result = await transactionsQueries.createOrUpdateTransactions(mockTransactions);

      // Assert
      expect(result).toEqual({ success: false, error: dbError });
      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
      expect(mockClient.release).toHaveBeenCalled();
      expect(logger.error).toHaveBeenCalledWith('Batch insert failed:', dbError);
    });

    it('should optimize with batch account lookup for 300 transactions', async () => {
      // Arrange - Create 300 transactions across 5 accounts
      const mockTransactions = Array.from({ length: 300 }, (_, i) => ({
        account_id: `plaid-account-${(i % 5) + 1}`, // 5 unique accounts
        amount: i * 10.5,
        iso_currency_code: 'USD',
        date: '2025-12-10',
        name: `Transaction ${i}`,
        transaction_id: `txn-${i}`,
        payment_channel: 'online',
        pending: false,
      }));

      const mockAccounts = Array.from({ length: 5 }, (_, i) => ({
        id: 101 + i,
        plaid_account_id: `plaid-account-${i + 1}`,
      }));

      mockClient.query
        .mockResolvedValueOnce({ rows: [] }) // BEGIN
        .mockResolvedValueOnce({ rows: mockAccounts }) // Single account lookup
        .mockResolvedValueOnce({ rows: [] }) // Single batch INSERT
        .mockResolvedValueOnce({ rows: [] }); // COMMIT

      // Act
      const result = await transactionsQueries.createOrUpdateTransactions(mockTransactions);

      // Assert
      expect(result).toEqual({ success: true });

      // Verify only 4 queries total (not 600!)
      expect(mockClient.query).toHaveBeenCalledTimes(4);

      // Verify account lookup retrieved 5 unique accounts
      expect(mockClient.query).toHaveBeenNthCalledWith(2, {
        text: expect.stringContaining('plaid_account_id = ANY'),
        values: [[
          'plaid-account-1',
          'plaid-account-2',
          'plaid-account-3',
          'plaid-account-4',
          'plaid-account-5',
        ]],
      });

      // Verify batch INSERT has all 300 transactions (4500 values: 300 × 15)
      const insertCall = mockClient.query.mock.calls[2][0];
      expect(insertCall.values.length).toBe(4500);
    });
  });

  describe('deleteTransactions - Batch Operations', () => {
    it('should handle empty transaction IDs array', async () => {
      // Act
      await transactionsQueries.deleteTransactions([]);

      // Assert
      expect(db.query).not.toHaveBeenCalled();
    });

    it('should batch delete multiple transactions in single query', async () => {
      // Arrange
      const transactionIds = ['txn-1', 'txn-2', 'txn-3'];

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      await transactionsQueries.deleteTransactions(transactionIds);

      // Assert
      expect(db.query).toHaveBeenCalledTimes(1);
      expect(db.query).toHaveBeenCalledWith({
        text: 'DELETE FROM transactions_table WHERE transaction_id = ANY($1::text[])',
        values: [transactionIds],
      });
    });

    it('should batch delete 100 transactions in single query', async () => {
      // Arrange
      const transactionIds = Array.from({ length: 100 }, (_, i) => `txn-${i}`);

      db.query.mockResolvedValueOnce({ rows: [] });

      // Act
      await transactionsQueries.deleteTransactions(transactionIds);

      // Assert
      expect(db.query).toHaveBeenCalledTimes(1);
      expect(db.query).toHaveBeenCalledWith({
        text: 'DELETE FROM transactions_table WHERE transaction_id = ANY($1::text[])',
        values: [transactionIds],
      });
    });
  });
});
