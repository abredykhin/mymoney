import {
  setupTestEnvironment,
  assertEquals,
  assertExists,
  createMockSupabaseClient,
} from "./test-utils.ts";
import { updateTransactionRecurringFlags, updateProfileRecurringSummary } from "./recurring.ts";

// Load environment before tests
await setupTestEnvironment();

// =============================================================================
// updateTransactionRecurringFlags() Tests
// =============================================================================

Deno.test("updateTransactionRecurringFlags: resets all transactions to non-recurring first", async () => {
  let resetCalled = false;
  const mockUpdates: any[] = [];

  const mockClient = {
    from: (table: string) => {
      if (table === 'transactions_table') {
        return {
          update: (data: any) => {
            mockUpdates.push({ table, data });
            return {
              eq: (column: string, value: any) => {
                if (!resetCalled && data.is_recurring === false) {
                  resetCalled = true;
                }
                return Promise.resolve({ data: null, error: null });
              },
            };
          },
          in: (column: string, values: any[]) => {
            return Promise.resolve({ data: null, error: null });
          },
        };
      }
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => Promise.resolve({ data: [], error: null }),
            }),
          }),
        };
      }
      return {};
    },
  } as any;

  await updateTransactionRecurringFlags(mockClient, 'user-1');

  assertEquals(resetCalled, true, 'Should reset all transactions to non-recurring');
});

Deno.test("updateTransactionRecurringFlags: marks transactions from active stream with user_marked_recurring=true", async () => {
  let markedRecurring = false;
  const transactionIds = ['tx-1', 'tx-2'];

  const mockClient = {
    from: (table: string) => {
      if (table === 'transactions_table') {
        return {
          update: (data: any) => ({
            eq: () => Promise.resolve({ data: null, error: null }),
            in: (column: string, values: any[]) => {
              if (data.is_recurring === true && column === 'id' && values.length === 2) {
                markedRecurring = true;
              }
              return Promise.resolve({ data: null, error: null });
            },
          }),
        };
      }
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => Promise.resolve({
                data: [{
                  id: 'stream-1',
                  user_marked_recurring: true,
                  is_excluded: false,
                  status: 'ACTIVE',
                  is_active: true,
                }],
                error: null,
              }),
            }),
          }),
        };
      }
      if (table === 'recurring_stream_transactions_table') {
        return {
          select: () => ({
            eq: () => Promise.resolve({
              data: [
                { transaction_id: 'tx-1' },
                { transaction_id: 'tx-2' },
              ],
              error: null,
            }),
          }),
        };
      }
      return {};
    },
  } as any;

  await updateTransactionRecurringFlags(mockClient, 'user-1');

  assertEquals(markedRecurring, true, 'Should mark transactions as recurring');
});

Deno.test("updateTransactionRecurringFlags: marks transactions from active stream with user_marked_recurring=null (auto-detected)", async () => {
  let markedRecurring = false;

  const mockClient = {
    from: (table: string) => {
      if (table === 'transactions_table') {
        return {
          update: (data: any) => ({
            eq: () => Promise.resolve({ data: null, error: null }),
            in: (column: string, values: any[]) => {
              if (data.is_recurring === true) {
                markedRecurring = true;
              }
              return Promise.resolve({ data: null, error: null });
            },
          }),
        };
      }
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => Promise.resolve({
                data: [{
                  id: 'stream-1',
                  user_marked_recurring: null, // Auto-detected
                  is_excluded: false,
                  status: 'ACTIVE',
                  is_active: true,
                }],
                error: null,
              }),
            }),
          }),
        };
      }
      if (table === 'recurring_stream_transactions_table') {
        return {
          select: () => ({
            eq: () => Promise.resolve({
              data: [{ transaction_id: 'tx-1' }],
              error: null,
            }),
          }),
        };
      }
      return {};
    },
  } as any;

  await updateTransactionRecurringFlags(mockClient, 'user-1');

  assertEquals(markedRecurring, true, 'Should mark auto-detected transactions as recurring');
});

Deno.test("updateTransactionRecurringFlags: does NOT mark transactions when user_marked_recurring=false", async () => {
  let markedRecurring = false;

  const mockClient = {
    from: (table: string) => {
      if (table === 'transactions_table') {
        return {
          update: (data: any) => ({
            eq: () => Promise.resolve({ data: null, error: null }),
            in: (column: string, values: any[]) => {
              if (data.is_recurring === true) {
                markedRecurring = true;
              }
              return Promise.resolve({ data: null, error: null });
            },
          }),
        };
      }
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => Promise.resolve({
                data: [{
                  id: 'stream-1',
                  user_marked_recurring: false, // User explicitly unmarked
                  is_excluded: false,
                  status: 'ACTIVE',
                  is_active: true,
                }],
                error: null,
              }),
            }),
          }),
        };
      }
      return {};
    },
  } as any;

  await updateTransactionRecurringFlags(mockClient, 'user-1');

  assertEquals(markedRecurring, false, 'Should NOT mark when user_marked_recurring=false');
});

Deno.test("updateTransactionRecurringFlags: does NOT mark transactions when is_excluded=true", async () => {
  let markedRecurring = false;

  const mockClient = {
    from: (table: string) => {
      if (table === 'transactions_table') {
        return {
          update: (data: any) => ({
            eq: () => Promise.resolve({ data: null, error: null }),
            in: (column: string, values: any[]) => {
              if (data.is_recurring === true) {
                markedRecurring = true;
              }
              return Promise.resolve({ data: null, error: null });
            },
          }),
        };
      }
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => Promise.resolve({
                data: [{
                  id: 'stream-1',
                  user_marked_recurring: null,
                  is_excluded: true, // User excluded this stream
                  status: 'ACTIVE',
                  is_active: true,
                }],
                error: null,
              }),
            }),
          }),
        };
      }
      return {};
    },
  } as any;

  await updateTransactionRecurringFlags(mockClient, 'user-1');

  assertEquals(markedRecurring, false, 'Should NOT mark when is_excluded=true');
});

Deno.test("updateTransactionRecurringFlags: does NOT mark transactions when status=TOMBSTONED", async () => {
  let markedRecurring = false;

  const mockClient = {
    from: (table: string) => {
      if (table === 'transactions_table') {
        return {
          update: (data: any) => ({
            eq: () => Promise.resolve({ data: null, error: null }),
            in: (column: string, values: any[]) => {
              if (data.is_recurring === true) {
                markedRecurring = true;
              }
              return Promise.resolve({ data: null, error: null });
            },
          }),
        };
      }
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => Promise.resolve({
                data: [{
                  id: 'stream-1',
                  user_marked_recurring: null,
                  is_excluded: false,
                  status: 'TOMBSTONED', // Ended subscription
                  is_active: true,
                }],
                error: null,
              }),
            }),
          }),
        };
      }
      return {};
    },
  } as any;

  await updateTransactionRecurringFlags(mockClient, 'user-1');

  assertEquals(markedRecurring, false, 'Should NOT mark when status=TOMBSTONED');
});

Deno.test("updateTransactionRecurringFlags: does NOT mark transactions when is_active=false", async () => {
  let markedRecurring = false;

  const mockClient = {
    from: (table: string) => {
      if (table === 'transactions_table') {
        return {
          update: (data: any) => ({
            eq: () => Promise.resolve({ data: null, error: null }),
            in: (column: string, values: any[]) => {
              if (data.is_recurring === true) {
                markedRecurring = true;
              }
              return Promise.resolve({ data: null, error: null });
            },
          }),
        };
      }
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => Promise.resolve({
                data: [{
                  id: 'stream-1',
                  user_marked_recurring: null,
                  is_excluded: false,
                  status: 'ACTIVE',
                  is_active: false, // Inactive stream
                }],
                error: null,
              }),
            }),
          }),
        };
      }
      return {};
    },
  } as any;

  await updateTransactionRecurringFlags(mockClient, 'user-1');

  assertEquals(markedRecurring, false, 'Should NOT mark when is_active=false');
});

Deno.test("updateTransactionRecurringFlags: handles empty stream list gracefully", async () => {
  const mockClient = {
    from: (table: string) => {
      if (table === 'transactions_table') {
        return {
          update: () => ({
            eq: () => Promise.resolve({ data: null, error: null }),
          }),
        };
      }
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => Promise.resolve({ data: [], error: null }), // No streams
            }),
          }),
        };
      }
      return {};
    },
  } as any;

  // Should not throw
  await updateTransactionRecurringFlags(mockClient, 'user-1');
});

Deno.test("updateTransactionRecurringFlags: handles null stream list gracefully", async () => {
  const mockClient = {
    from: (table: string) => {
      if (table === 'transactions_table') {
        return {
          update: () => ({
            eq: () => Promise.resolve({ data: null, error: null }),
          }),
        };
      }
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => Promise.resolve({ data: null, error: null }), // Null data
            }),
          }),
        };
      }
      return {};
    },
  } as any;

  // Should not throw
  await updateTransactionRecurringFlags(mockClient, 'user-1');
});

Deno.test("updateTransactionRecurringFlags: skips streams with no linked transactions", async () => {
  let markedRecurring = false;

  const mockClient = {
    from: (table: string) => {
      if (table === 'transactions_table') {
        return {
          update: (data: any) => ({
            eq: () => Promise.resolve({ data: null, error: null }),
            in: (column: string, values: any[]) => {
              if (data.is_recurring === true) {
                markedRecurring = true;
              }
              return Promise.resolve({ data: null, error: null });
            },
          }),
        };
      }
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => Promise.resolve({
                data: [{
                  id: 'stream-1',
                  user_marked_recurring: true,
                  is_excluded: false,
                  status: 'ACTIVE',
                  is_active: true,
                }],
                error: null,
              }),
            }),
          }),
        };
      }
      if (table === 'recurring_stream_transactions_table') {
        return {
          select: () => ({
            eq: () => Promise.resolve({
              data: [], // No linked transactions
              error: null,
            }),
          }),
        };
      }
      return {};
    },
  } as any;

  await updateTransactionRecurringFlags(mockClient, 'user-1');

  assertEquals(markedRecurring, false, 'Should not mark when no transactions linked');
});

Deno.test("updateTransactionRecurringFlags: handles multiple streams correctly", async () => {
  const markedTransactions: string[][] = [];

  const mockClient = {
    from: (table: string) => {
      if (table === 'transactions_table') {
        return {
          update: (data: any) => ({
            eq: () => Promise.resolve({ data: null, error: null }),
            in: (column: string, values: any[]) => {
              if (data.is_recurring === true && column === 'id') {
                markedTransactions.push(values);
              }
              return Promise.resolve({ data: null, error: null });
            },
          }),
        };
      }
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => Promise.resolve({
                data: [
                  {
                    id: 'stream-1',
                    user_marked_recurring: true,
                    is_excluded: false,
                    status: 'ACTIVE',
                    is_active: true,
                  },
                  {
                    id: 'stream-2',
                    user_marked_recurring: null,
                    is_excluded: false,
                    status: 'ACTIVE',
                    is_active: true,
                  },
                  {
                    id: 'stream-3',
                    user_marked_recurring: null,
                    is_excluded: true, // Should be skipped
                    status: 'ACTIVE',
                    is_active: true,
                  },
                ],
                error: null,
              }),
            }),
          }),
        };
      }
      if (table === 'recurring_stream_transactions_table') {
        return {
          select: () => ({
            eq: (column: string, value: any) => {
              if (value === 'stream-1') {
                return Promise.resolve({
                  data: [{ transaction_id: 'tx-1' }, { transaction_id: 'tx-2' }],
                  error: null,
                });
              } else if (value === 'stream-2') {
                return Promise.resolve({
                  data: [{ transaction_id: 'tx-3' }],
                  error: null,
                });
              }
              return Promise.resolve({ data: [], error: null });
            },
          }),
        };
      }
      return {};
    },
  } as any;

  await updateTransactionRecurringFlags(mockClient, 'user-1');

  assertEquals(markedTransactions.length, 2, 'Should mark transactions from 2 valid streams');
  assertEquals(markedTransactions[0].length, 2, 'First stream should have 2 transactions');
  assertEquals(markedTransactions[1].length, 1, 'Second stream should have 1 transaction');
});

// =============================================================================
// updateProfileRecurringSummary() Tests
// =============================================================================

Deno.test("updateProfileRecurringSummary: calculates monthly income correctly", async () => {
  let profileUpdate: any = null;

  const mockClient = {
    from: (table: string) => {
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                neq: () => Promise.resolve({
                  data: [
                    {
                      type: 'income',
                      monthly_amount: '5000.00',
                      user_marked_recurring: null,
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                    {
                      type: 'income',
                      monthly_amount: '1000.00',
                      user_marked_recurring: true,
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                  ],
                  error: null,
                }),
              }),
            }),
          }),
        };
      }
      if (table === 'profiles_table') {
        return {
          update: (data: any) => {
            profileUpdate = data;
            return {
              eq: () => Promise.resolve({ data: null, error: null }),
            };
          },
        };
      }
      return {};
    },
  } as any;

  await updateProfileRecurringSummary(mockClient, 'user-1');

  assertExists(profileUpdate);
  assertEquals(profileUpdate.monthly_income, 6000, 'Should sum all income streams');
  assertEquals(profileUpdate.monthly_mandatory_expenses, 0, 'Should have no expenses');
});

Deno.test("updateProfileRecurringSummary: calculates monthly expenses correctly", async () => {
  let profileUpdate: any = null;

  const mockClient = {
    from: (table: string) => {
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                neq: () => Promise.resolve({
                  data: [
                    {
                      type: 'expense',
                      monthly_amount: '1500.00',
                      user_marked_recurring: null,
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                    {
                      type: 'expense',
                      monthly_amount: '99.99',
                      user_marked_recurring: true,
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                  ],
                  error: null,
                }),
              }),
            }),
          }),
        };
      }
      if (table === 'profiles_table') {
        return {
          update: (data: any) => {
            profileUpdate = data;
            return {
              eq: () => Promise.resolve({ data: null, error: null }),
            };
          },
        };
      }
      return {};
    },
  } as any;

  await updateProfileRecurringSummary(mockClient, 'user-1');

  assertExists(profileUpdate);
  assertEquals(profileUpdate.monthly_income, 0, 'Should have no income');
  assertEquals(profileUpdate.monthly_mandatory_expenses, 1599.99, 'Should sum all expense streams');
});

Deno.test("updateProfileRecurringSummary: separates income and expense correctly", async () => {
  let profileUpdate: any = null;

  const mockClient = {
    from: (table: string) => {
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                neq: () => Promise.resolve({
                  data: [
                    {
                      type: 'income',
                      monthly_amount: '5000.00',
                      user_marked_recurring: null,
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                    {
                      type: 'expense',
                      monthly_amount: '1500.00',
                      user_marked_recurring: null,
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                    {
                      type: 'income',
                      monthly_amount: '500.00',
                      user_marked_recurring: true,
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                    {
                      type: 'expense',
                      monthly_amount: '100.00',
                      user_marked_recurring: true,
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                  ],
                  error: null,
                }),
              }),
            }),
          }),
        };
      }
      if (table === 'profiles_table') {
        return {
          update: (data: any) => {
            profileUpdate = data;
            return {
              eq: () => Promise.resolve({ data: null, error: null }),
            };
          },
        };
      }
      return {};
    },
  } as any;

  await updateProfileRecurringSummary(mockClient, 'user-1');

  assertExists(profileUpdate);
  assertEquals(profileUpdate.monthly_income, 5500, 'Should sum only income streams');
  assertEquals(profileUpdate.monthly_mandatory_expenses, 1600, 'Should sum only expense streams');
});

Deno.test("updateProfileRecurringSummary: respects user_marked_recurring=false (user excluded)", async () => {
  let profileUpdate: any = null;

  const mockClient = {
    from: (table: string) => {
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                neq: () => Promise.resolve({
                  data: [
                    {
                      type: 'income',
                      monthly_amount: '5000.00',
                      user_marked_recurring: false, // User explicitly excluded
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                  ],
                  error: null,
                }),
              }),
            }),
          }),
        };
      }
      if (table === 'profiles_table') {
        return {
          update: (data: any) => {
            profileUpdate = data;
            return {
              eq: () => Promise.resolve({ data: null, error: null }),
            };
          },
        };
      }
      return {};
    },
  } as any;

  await updateProfileRecurringSummary(mockClient, 'user-1');

  assertExists(profileUpdate);
  assertEquals(profileUpdate.monthly_income, 0, 'Should exclude when user_marked_recurring=false');
});

Deno.test("updateProfileRecurringSummary: respects is_excluded=true", async () => {
  let profileUpdate: any = null;

  const mockClient = {
    from: (table: string) => {
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                neq: () => Promise.resolve({
                  data: [
                    {
                      type: 'expense',
                      monthly_amount: '100.00',
                      user_marked_recurring: null,
                      is_excluded: true, // User excluded this stream
                      status: 'ACTIVE',
                    },
                  ],
                  error: null,
                }),
              }),
            }),
          }),
        };
      }
      if (table === 'profiles_table') {
        return {
          update: (data: any) => {
            profileUpdate = data;
            return {
              eq: () => Promise.resolve({ data: null, error: null }),
            };
          },
        };
      }
      return {};
    },
  } as any;

  await updateProfileRecurringSummary(mockClient, 'user-1');

  assertExists(profileUpdate);
  assertEquals(profileUpdate.monthly_mandatory_expenses, 0, 'Should exclude when is_excluded=true');
});

Deno.test("updateProfileRecurringSummary: excludes TOMBSTONED streams via query", async () => {
  let profileUpdate: any = null;

  const mockClient = {
    from: (table: string) => {
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                neq: (column: string, value: any) => {
                  // The query filters out TOMBSTONED items, so return empty array
                  // to simulate that TOMBSTONED streams are excluded by the query
                  if (column === 'status' && value === 'TOMBSTONED') {
                    return Promise.resolve({
                      data: [], // Query excludes TOMBSTONED, returns nothing
                      error: null,
                    });
                  }
                  return Promise.resolve({ data: [], error: null });
                },
              }),
            }),
          }),
        };
      }
      if (table === 'profiles_table') {
        return {
          update: (data: any) => {
            profileUpdate = data;
            return {
              eq: () => Promise.resolve({ data: null, error: null }),
            };
          },
        };
      }
      return {};
    },
  } as any;

  await updateProfileRecurringSummary(mockClient, 'user-1');

  assertExists(profileUpdate);
  assertEquals(profileUpdate.monthly_mandatory_expenses, 0, 'TOMBSTONED streams should be excluded by query');
});

Deno.test("updateProfileRecurringSummary: handles zero recurring items", async () => {
  let profileUpdate: any = null;

  const mockClient = {
    from: (table: string) => {
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                neq: () => Promise.resolve({
                  data: [], // No streams
                  error: null,
                }),
              }),
            }),
          }),
        };
      }
      if (table === 'profiles_table') {
        return {
          update: (data: any) => {
            profileUpdate = data;
            return {
              eq: () => Promise.resolve({ data: null, error: null }),
            };
          },
        };
      }
      return {};
    },
  } as any;

  await updateProfileRecurringSummary(mockClient, 'user-1');

  assertExists(profileUpdate);
  assertEquals(profileUpdate.monthly_income, 0, 'Should be zero when no streams');
  assertEquals(profileUpdate.monthly_mandatory_expenses, 0, 'Should be zero when no streams');
});

Deno.test("updateProfileRecurringSummary: handles null stream list", async () => {
  let profileUpdate: any = null;

  const mockClient = {
    from: (table: string) => {
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                neq: () => Promise.resolve({
                  data: null, // Null data
                  error: null,
                }),
              }),
            }),
          }),
        };
      }
      if (table === 'profiles_table') {
        return {
          update: (data: any) => {
            profileUpdate = data;
            return {
              eq: () => Promise.resolve({ data: null, error: null }),
            };
          },
        };
      }
      return {};
    },
  } as any;

  await updateProfileRecurringSummary(mockClient, 'user-1');

  assertExists(profileUpdate);
  assertEquals(profileUpdate.monthly_income, 0, 'Should be zero when data is null');
  assertEquals(profileUpdate.monthly_mandatory_expenses, 0, 'Should be zero when data is null');
});

Deno.test("updateProfileRecurringSummary: ignores unknown stream types", async () => {
  let profileUpdate: any = null;

  const mockClient = {
    from: (table: string) => {
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                neq: () => Promise.resolve({
                  data: [
                    {
                      type: 'income',
                      monthly_amount: '1000.00',
                      user_marked_recurring: null,
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                    {
                      type: 'unknown_type', // Invalid type
                      monthly_amount: '500.00',
                      user_marked_recurring: null,
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                  ],
                  error: null,
                }),
              }),
            }),
          }),
        };
      }
      if (table === 'profiles_table') {
        return {
          update: (data: any) => {
            profileUpdate = data;
            return {
              eq: () => Promise.resolve({ data: null, error: null }),
            };
          },
        };
      }
      return {};
    },
  } as any;

  await updateProfileRecurringSummary(mockClient, 'user-1');

  assertExists(profileUpdate);
  assertEquals(profileUpdate.monthly_income, 1000, 'Should only count valid income');
  assertEquals(profileUpdate.monthly_mandatory_expenses, 0, 'Should ignore unknown types');
});

Deno.test("updateProfileRecurringSummary: updates profile with updated_at timestamp", async () => {
  let profileUpdate: any = null;

  const mockClient = {
    from: (table: string) => {
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                neq: () => Promise.resolve({
                  data: [],
                  error: null,
                }),
              }),
            }),
          }),
        };
      }
      if (table === 'profiles_table') {
        return {
          update: (data: any) => {
            profileUpdate = data;
            return {
              eq: () => Promise.resolve({ data: null, error: null }),
            };
          },
        };
      }
      return {};
    },
  } as any;

  await updateProfileRecurringSummary(mockClient, 'user-1');

  assertExists(profileUpdate);
  assertExists(profileUpdate.updated_at, 'Should include updated_at timestamp');

  // Verify it's a valid ISO timestamp
  const timestamp = new Date(profileUpdate.updated_at);
  assertEquals(timestamp instanceof Date && !isNaN(timestamp.getTime()), true, 'Should be valid ISO timestamp');
});

Deno.test("updateProfileRecurringSummary: handles decimal amounts correctly", async () => {
  let profileUpdate: any = null;

  const mockClient = {
    from: (table: string) => {
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                neq: () => Promise.resolve({
                  data: [
                    {
                      type: 'income',
                      monthly_amount: '1234.56',
                      user_marked_recurring: null,
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                    {
                      type: 'expense',
                      monthly_amount: '99.99',
                      user_marked_recurring: null,
                      is_excluded: false,
                      status: 'ACTIVE',
                    },
                  ],
                  error: null,
                }),
              }),
            }),
          }),
        };
      }
      if (table === 'profiles_table') {
        return {
          update: (data: any) => {
            profileUpdate = data;
            return {
              eq: () => Promise.resolve({ data: null, error: null }),
            };
          },
        };
      }
      return {};
    },
  } as any;

  await updateProfileRecurringSummary(mockClient, 'user-1');

  assertExists(profileUpdate);
  assertEquals(profileUpdate.monthly_income, 1234.56, 'Should handle decimal income correctly');
  assertEquals(profileUpdate.monthly_mandatory_expenses, 99.99, 'Should handle decimal expenses correctly');
});

Deno.test("updateProfileRecurringSummary: user_marked_recurring=true overrides is_excluded", async () => {
  let profileUpdate: any = null;

  const mockClient = {
    from: (table: string) => {
      if (table === 'recurring_streams_table') {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                neq: () => Promise.resolve({
                  data: [
                    {
                      type: 'income',
                      monthly_amount: '1000.00',
                      user_marked_recurring: true, // User explicitly marked as recurring
                      is_excluded: true, // But also excluded - user_marked should win
                      status: 'ACTIVE',
                    },
                  ],
                  error: null,
                }),
              }),
            }),
          }),
        };
      }
      if (table === 'profiles_table') {
        return {
          update: (data: any) => {
            profileUpdate = data;
            return {
              eq: () => Promise.resolve({ data: null, error: null }),
            };
          },
        };
      }
      return {};
    },
  } as any;

  await updateProfileRecurringSummary(mockClient, 'user-1');

  assertExists(profileUpdate);
  assertEquals(profileUpdate.monthly_income, 1000, 'user_marked_recurring=true should override is_excluded');
});
