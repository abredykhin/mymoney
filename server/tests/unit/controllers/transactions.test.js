/**
 * @file Unit tests for syncTransactions controller
 */

// Mock dependencies before importing controller
jest.mock('@/plaid/loggingPlaidClient', () => ({
  accountsGet: jest.fn(),
  transactionsSync: jest.fn(),
}));

jest.mock('@/db/queries', () => ({
  retrieveItemByPlaidItemId: jest.fn(),
  createAccounts: jest.fn(),
  createOrUpdateTransactions: jest.fn(),
  deleteTransactions: jest.fn(),
  updateItemTransactionsCursor: jest.fn(),
}));

jest.mock('debug', () => {
  const mockDebug = jest.fn().mockReturnValue(jest.fn());
  mockDebug.extend = jest.fn().mockReturnValue(jest.fn());
  return mockDebug;
});

jest.mock('@/utils/logger', () => ({
  info: jest.fn(),
  error: jest.fn(),
}));

// Import the module and mocked dependencies
const syncTransactions = require('@/controllers/transactions');
const plaid = require('@/plaid/loggingPlaidClient');
const queries = require('@/db/queries');
const logger = require('@/utils/logger');

describe('Sync Transactions Controller', () => {
  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
  });

  describe('syncTransactions', () => {
    it('should sync transactions successfully when item exists and has no transactions yet', async () => {
      // Arrange
      const plaidItemId = 'item-sandbox-123';
      const accessToken = 'access-sandbox-123';

      // Mock item retrieval
      queries.retrieveItemByPlaidItemId.mockResolvedValue({
        plaid_access_token: accessToken,
        transactions_cursor: null, // No cursor yet (first sync)
      });

      // Mock Plaid transactionsSync response (single page of results)
      plaid.transactionsSync.mockResolvedValueOnce({
        data: {
          added: [
            { transaction_id: 'tx1', account_id: 'acc1', amount: 100 },
            { transaction_id: 'tx2', account_id: 'acc1', amount: 200 },
          ],
          modified: [],
          removed: [],
          has_more: false,
          next_cursor: 'cursor-123',
        },
      });

      // Mock Plaid accountsGet response
      plaid.accountsGet.mockResolvedValue({
        data: {
          accounts: [
            {
              account_id: 'acc1',
              name: 'Checking',
              type: 'depository',
              balances: {},
            },
          ],
        },
      });

      // Mock database operations
      queries.createAccounts.mockResolvedValue([
        { id: 1, plaid_account_id: 'acc1' },
      ]);
      queries.createOrUpdateTransactions.mockResolvedValue(2);
      queries.deleteTransactions.mockResolvedValue(0);
      queries.updateItemTransactionsCursor.mockResolvedValue(true);

      // Act
      const result = await syncTransactions(plaidItemId);

      // Assert
      // Verify item was retrieved
      expect(queries.retrieveItemByPlaidItemId).toHaveBeenCalledWith(
        plaidItemId
      );

      // Verify Plaid API was called correctly
      expect(plaid.transactionsSync).toHaveBeenCalledWith({
        access_token: accessToken,
        cursor: null,
        count: 100,
        options: {
          include_personal_finance_category: true,
        },
      });

      // Verify accounts were fetched and stored
      expect(plaid.accountsGet).toHaveBeenCalledWith({
        access_token: accessToken,
      });
      expect(queries.createAccounts).toHaveBeenCalledWith(
        plaidItemId,
        expect.any(Array)
      );

      // Verify transactions were processed
      expect(queries.createOrUpdateTransactions).toHaveBeenCalledWith(
        expect.arrayContaining([
          expect.objectContaining({ transaction_id: 'tx1' }),
          expect.objectContaining({ transaction_id: 'tx2' }),
        ])
      );

      // Verify cursor was updated
      expect(queries.updateItemTransactionsCursor).toHaveBeenCalledWith(
        plaidItemId,
        'cursor-123'
      );

      // Verify correct counts were returned
      expect(result).toEqual({
        addedCount: 2,
        modifiedCount: 0,
        removedCount: 0,
      });
    });

    it('should handle pagination when has_more is true', async () => {
      // Arrange
      const plaidItemId = 'item-sandbox-123';
      const accessToken = 'access-sandbox-123';

      // Mock item retrieval
      queries.retrieveItemByPlaidItemId.mockResolvedValue({
        plaid_access_token: accessToken,
        transactions_cursor: 'existing-cursor',
      });

      // Mock Plaid transactionsSync responses (two pages)
      plaid.transactionsSync
        .mockResolvedValueOnce({
          data: {
            added: [{ transaction_id: 'tx1', account_id: 'acc1', amount: 100 }],
            modified: [],
            removed: [],
            has_more: true, // More pages available
            next_cursor: 'cursor-page2',
          },
        })
        .mockResolvedValueOnce({
          data: {
            added: [{ transaction_id: 'tx2', account_id: 'acc1', amount: 200 }],
            modified: [],
            removed: [],
            has_more: false, // Last page
            next_cursor: 'cursor-final',
          },
        });

      // Mock Plaid accountsGet response
      plaid.accountsGet.mockResolvedValue({
        data: {
          accounts: [
            {
              account_id: 'acc1',
              name: 'Checking',
              type: 'depository',
              balances: {},
            },
          ],
        },
      });

      // Mock database operations
      queries.createAccounts.mockResolvedValue([
        { id: 1, plaid_account_id: 'acc1' },
      ]);
      queries.createOrUpdateTransactions.mockResolvedValue(2);
      queries.deleteTransactions.mockResolvedValue(0);
      queries.updateItemTransactionsCursor.mockResolvedValue(true);

      // Act
      const result = await syncTransactions(plaidItemId);

      // Assert
      // Verify Plaid API was called twice with different cursors
      expect(plaid.transactionsSync).toHaveBeenCalledTimes(2);
      expect(plaid.transactionsSync).toHaveBeenNthCalledWith(1, {
        access_token: accessToken,
        cursor: 'existing-cursor',
        count: 100,
        options: {
          include_personal_finance_category: true,
        },
      });
      expect(plaid.transactionsSync).toHaveBeenNthCalledWith(2, {
        access_token: accessToken,
        cursor: 'cursor-page2',
        count: 100,
        options: {
          include_personal_finance_category: true,
        },
      });

      // Verify transactions from both pages were processed
      expect(queries.createOrUpdateTransactions).toHaveBeenCalledWith(
        expect.arrayContaining([
          expect.objectContaining({ transaction_id: 'tx1' }),
          expect.objectContaining({ transaction_id: 'tx2' }),
        ])
      );

      // Verify final cursor was updated
      expect(queries.updateItemTransactionsCursor).toHaveBeenCalledWith(
        plaidItemId,
        'cursor-final'
      );

      // Verify correct counts were returned
      expect(result).toEqual({
        addedCount: 2,
        modifiedCount: 0,
        removedCount: 0,
      });
    });

    it('should handle modified and removed transactions', async () => {
      // Arrange
      const plaidItemId = 'item-sandbox-123';
      const accessToken = 'access-sandbox-123';

      // Mock item retrieval
      queries.retrieveItemByPlaidItemId.mockResolvedValue({
        plaid_access_token: accessToken,
        transactions_cursor: 'existing-cursor',
      });

      // Mock Plaid transactionsSync response with modified and removed transactions
      plaid.transactionsSync.mockResolvedValueOnce({
        data: {
          added: [{ transaction_id: 'tx1', account_id: 'acc1', amount: 100 }],
          modified: [
            { transaction_id: 'tx2', account_id: 'acc1', amount: 250 },
          ], // Modified amount
          removed: [{ transaction_id: 'tx3' }], // Removed transaction
          has_more: false,
          next_cursor: 'cursor-123',
        },
      });

      // Mock Plaid accountsGet response
      plaid.accountsGet.mockResolvedValue({
        data: {
          accounts: [
            {
              account_id: 'acc1',
              name: 'Checking',
              type: 'depository',
              balances: {},
            },
          ],
        },
      });

      // Mock database operations
      queries.createAccounts.mockResolvedValue([
        { id: 1, plaid_account_id: 'acc1' },
      ]);
      queries.createOrUpdateTransactions.mockResolvedValue(2);
      queries.deleteTransactions.mockResolvedValue(1);
      queries.updateItemTransactionsCursor.mockResolvedValue(true);

      // Act
      const result = await syncTransactions(plaidItemId);

      // Assert
      // Verify all transaction types were handled
      expect(queries.createOrUpdateTransactions).toHaveBeenCalledWith(
        expect.arrayContaining([
          expect.objectContaining({ transaction_id: 'tx1' }), // Added
          expect.objectContaining({ transaction_id: 'tx2' }), // Modified
        ])
      );

      expect(queries.deleteTransactions).toHaveBeenCalledWith(
        expect.arrayContaining([
          expect.objectContaining({ transaction_id: 'tx3' }), // Removed
        ])
      );

      // Verify correct counts were returned
      expect(result).toEqual({
        addedCount: 1,
        modifiedCount: 1,
        removedCount: 1,
      });
    });

    it('should handle error when item is not found', async () => {
      // Arrange
      const plaidItemId = 'nonexistent-item';

      // Mock item retrieval - item not found
      queries.retrieveItemByPlaidItemId.mockResolvedValue(null);

      // Act
      const result = await syncTransactions(plaidItemId);

      // Assert
      // Verify item was searched for
      expect(queries.retrieveItemByPlaidItemId).toHaveBeenCalledWith(
        plaidItemId
      );

      // Verify error was logged
      expect(logger.error).toHaveBeenCalledWith(
        expect.stringContaining('not found in db')
      );

      // Verify no further processing occurred
      expect(plaid.transactionsSync).not.toHaveBeenCalled();
      expect(plaid.accountsGet).not.toHaveBeenCalled();
      expect(queries.createAccounts).not.toHaveBeenCalled();

      // Verify undefined result
      expect(result).toBeUndefined();
    });

    it('should handle error when Plaid API call fails', async () => {
      // Arrange
      const plaidItemId = 'item-sandbox-123';
      const accessToken = 'access-sandbox-123';
      const existingCursor = 'existing-cursor';

      // Mock item retrieval
      queries.retrieveItemByPlaidItemId.mockResolvedValue({
        plaid_access_token: accessToken,
        transactions_cursor: existingCursor,
      });

      // Mock Plaid transactionsSync to throw an error
      const plaidError = new Error('API rate limit exceeded');
      plaid.transactionsSync.mockRejectedValue(plaidError);

      // Act
      const result = await syncTransactions(plaidItemId);

      // Assert
      // Verify error was logged
      expect(logger.error).toHaveBeenCalledWith(
        expect.stringContaining('Error fetching transactions')
      );

      // Verify accounts were still fetched
      expect(plaid.accountsGet).toHaveBeenCalled();

      // Verify no transactions were processed
      expect(queries.createOrUpdateTransactions).toHaveBeenCalledWith([]);
      expect(queries.deleteTransactions).toHaveBeenCalledWith([]);

      // Verify cursor was not updated (kept old value)
      expect(queries.updateItemTransactionsCursor).toHaveBeenCalledWith(
        plaidItemId,
        existingCursor
      );

      // Verify counts show no transactions processed
      expect(result).toEqual({
        addedCount: 0,
        modifiedCount: 0,
        removedCount: 0,
      });
    });
  });
});
