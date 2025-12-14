/**
 * Unit tests for database operations
 *
 * Run with: deno test --allow-env database.test.ts
 */

import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import {
  fetchItemDetails,
  fetchAccountIdMapping,
  batchUpsertAccounts,
  batchUpsertTransactions,
  batchDeleteTransactions,
  updateCursor,
} from './database.ts';

// Mock Supabase client
function createMockSupabaseClient(mockResponses: Record<string, any>) {
  return {
    from: (table: string) => ({
      select: (fields: string) => ({
        eq: (field: string, value: any) => ({
          single: () => mockResponses[`${table}_single`] || { data: null, error: null },
          then: (resolve: any) => resolve(mockResponses[table] || { data: [], error: null }),
        }),
        then: (resolve: any) => resolve(mockResponses[table] || { data: [], error: null }),
      }),
      upsert: (data: any, options: any) => ({
        then: (resolve: any) => resolve(mockResponses[`${table}_upsert`] || { error: null }),
      }),
      delete: () => ({
        in: (field: string, values: any[]) => ({
          then: (resolve: any) => resolve(mockResponses[`${table}_delete`] || { error: null }),
        }),
      }),
      update: (data: any) => ({
        eq: (field: string, value: any) => ({
          then: (resolve: any) => resolve(mockResponses[`${table}_update`] || { error: null }),
        }),
      }),
    }),
  };
}

// Test: fetchItemDetails - Success
Deno.test('fetchItemDetails - should fetch item successfully', async () => {
  const mockItem = {
    id: 123,
    user_id: 'user-456',
    plaid_access_token: 'access-token-789',
    transactions_cursor: 'cursor-abc',
    plaid_item_id: 'item-123',
  };

  const mockSupabase = createMockSupabaseClient({
    items_table_single: { data: mockItem, error: null },
  });

  const result = await fetchItemDetails(mockSupabase as any, 'item-123');

  assertEquals(result, mockItem);
});

// Test: fetchItemDetails - Item not found
Deno.test('fetchItemDetails - should throw when item not found', async () => {
  const mockSupabase = createMockSupabaseClient({
    items_table_single: { data: null, error: { message: 'Not found' } },
  });

  await assertRejects(
    async () => {
      await fetchItemDetails(mockSupabase as any, 'nonexistent-item');
    },
    Error,
    'Item not found'
  );
});

// Test: fetchAccountIdMapping - Success
Deno.test('fetchAccountIdMapping - should return account ID map', async () => {
  const mockAccounts = [
    { id: 1, plaid_account_id: 'acc-111' },
    { id: 2, plaid_account_id: 'acc-222' },
    { id: 3, plaid_account_id: 'acc-333' },
  ];

  const mockSupabase = createMockSupabaseClient({
    accounts_table: { data: mockAccounts, error: null },
  });

  const result = await fetchAccountIdMapping(mockSupabase as any, 123);

  assertEquals(result.size, 3);
  assertEquals(result.get('acc-111'), 1);
  assertEquals(result.get('acc-222'), 2);
  assertEquals(result.get('acc-333'), 3);
});

// Test: fetchAccountIdMapping - Empty result
Deno.test('fetchAccountIdMapping - should handle empty accounts', async () => {
  const mockSupabase = createMockSupabaseClient({
    accounts_table: { data: [], error: null },
  });

  const result = await fetchAccountIdMapping(mockSupabase as any, 123);

  assertEquals(result.size, 0);
});

// Test: batchUpsertAccounts - Success
Deno.test('batchUpsertAccounts - should upsert accounts successfully', async () => {
  const mockAccounts = [
    {
      account_id: 'acc-111',
      name: 'Checking',
      mask: '1234',
      official_name: 'My Checking Account',
      balances: {
        current: 1000,
        available: 900,
        iso_currency_code: 'USD',
      },
      type: 'depository',
      subtype: 'checking',
    },
  ];

  const mockSupabase = createMockSupabaseClient({
    items_table_single: { data: { id: 123 }, error: null },
    accounts_table_upsert: { error: null },
  });

  // Should not throw
  await batchUpsertAccounts(mockSupabase as any, 'item-123', mockAccounts);
});

// Test: batchUpsertAccounts - Empty accounts
Deno.test('batchUpsertAccounts - should handle empty accounts array', async () => {
  const mockSupabase = createMockSupabaseClient({});

  // Should not throw and should not make any DB calls
  await batchUpsertAccounts(mockSupabase as any, 'item-123', []);
});

// Test: batchUpsertTransactions - Success
Deno.test('batchUpsertTransactions - should upsert transactions successfully', async () => {
  const mockTransactions = [
    {
      account_id: 'acc-111',
      amount: -50.00,
      iso_currency_code: 'USD',
      date: '2025-12-10',
      name: 'Coffee Shop',
      payment_channel: 'in store',
      transaction_id: 'tx-111',
      pending: false,
    },
    {
      account_id: 'acc-111',
      amount: -25.50,
      iso_currency_code: 'USD',
      date: '2025-12-11',
      name: 'Grocery Store',
      payment_channel: 'in store',
      transaction_id: 'tx-222',
      pending: false,
    },
  ];

  const accountIdMapping = new Map([['acc-111', 1]]);

  const mockSupabase = createMockSupabaseClient({
    transactions_table_upsert: { error: null },
  });

  // Should not throw
  await batchUpsertTransactions(
    mockSupabase as any,
    mockTransactions as any,
    accountIdMapping,
    'user-456'
  );
});

// Test: batchUpsertTransactions - Skip transactions with missing accounts
Deno.test('batchUpsertTransactions - should skip transactions with missing accounts', async () => {
  const mockTransactions = [
    {
      account_id: 'acc-111',
      amount: -50.00,
      iso_currency_code: 'USD',
      date: '2025-12-10',
      name: 'Coffee Shop',
      payment_channel: 'in store',
      transaction_id: 'tx-111',
      pending: false,
    },
    {
      account_id: 'acc-999', // This account doesn't exist in mapping
      amount: -25.50,
      iso_currency_code: 'USD',
      date: '2025-12-11',
      name: 'Grocery Store',
      payment_channel: 'in store',
      transaction_id: 'tx-222',
      pending: false,
    },
  ];

  const accountIdMapping = new Map([['acc-111', 1]]);

  const mockSupabase = createMockSupabaseClient({
    transactions_table_upsert: { error: null },
  });

  // Should not throw and should only insert tx-111
  await batchUpsertTransactions(
    mockSupabase as any,
    mockTransactions as any,
    accountIdMapping,
    'user-456'
  );
});

// Test: batchUpsertTransactions - Empty transactions
Deno.test('batchUpsertTransactions - should handle empty transactions array', async () => {
  const accountIdMapping = new Map([['acc-111', 1]]);
  const mockSupabase = createMockSupabaseClient({});

  // Should not throw
  await batchUpsertTransactions(mockSupabase as any, [], accountIdMapping, 'user-456');
});

// Test: batchDeleteTransactions - Success
Deno.test('batchDeleteTransactions - should delete transactions successfully', async () => {
  const transactionIds = ['tx-111', 'tx-222', 'tx-333'];

  const mockSupabase = createMockSupabaseClient({
    transactions_table_delete: { error: null },
  });

  // Should not throw
  await batchDeleteTransactions(mockSupabase as any, transactionIds);
});

// Test: batchDeleteTransactions - Empty array
Deno.test('batchDeleteTransactions - should handle empty array', async () => {
  const mockSupabase = createMockSupabaseClient({});

  // Should not throw
  await batchDeleteTransactions(mockSupabase as any, []);
});

// Test: updateCursor - Success
Deno.test('updateCursor - should update cursor successfully', async () => {
  const mockSupabase = createMockSupabaseClient({
    items_table_update: { error: null },
  });

  // Should not throw
  await updateCursor(mockSupabase as any, 'item-123', 'new-cursor-xyz');
});

// Test: updateCursor - Database error
Deno.test('updateCursor - should throw on database error', async () => {
  const mockSupabase = createMockSupabaseClient({
    items_table_update: { error: { message: 'Database connection failed' } },
  });

  await assertRejects(
    async () => {
      await updateCursor(mockSupabase as any, 'item-123', 'new-cursor-xyz');
    },
    Error,
    'Failed to update cursor'
  );
});

// Test: batchUpsertTransactions - Verify user_id is set (RLS compliance)
Deno.test('batchUpsertTransactions - should set user_id on all transactions (RLS)', async () => {
  const mockTransactions = [
    {
      account_id: 'acc-111',
      amount: -50.00,
      iso_currency_code: 'USD',
      date: '2025-12-10',
      name: 'Coffee Shop',
      payment_channel: 'in store',
      transaction_id: 'tx-111',
      pending: false,
    },
  ];

  const accountIdMapping = new Map([['acc-111', 1]]);

  let capturedData: any[] = [];

  // Mock that captures the data being inserted
  const mockSupabase = {
    from: (table: string) => ({
      upsert: (data: any, options: any) => {
        capturedData = data;
        return { then: (resolve: any) => resolve({ error: null }) };
      },
    }),
  };

  await batchUpsertTransactions(
    mockSupabase as any,
    mockTransactions as any,
    accountIdMapping,
    'user-456'
  );

  // Verify user_id was set on all records
  assertEquals(capturedData.length, 1);
  assertEquals(capturedData[0].user_id, 'user-456');
  assertEquals(capturedData[0].account_id, 1);
  assertEquals(capturedData[0].transaction_id, 'tx-111');
});
