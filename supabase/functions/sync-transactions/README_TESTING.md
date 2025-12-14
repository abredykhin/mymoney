# Testing Guide for sync-transactions Edge Function

## Overview

This directory contains comprehensive tests for the transaction sync Edge Function. Tests are written using Deno's built-in test runner.

## Test Files

1. **database.test.ts** - Tests for database operations
   - Item fetching
   - Account ID mapping
   - Batch upsert operations
   - Cursor management
   - RLS compliance verification

2. **plaid.test.ts** - Tests for Plaid API integration
   - Transaction updates fetching
   - Account balance fetching
   - Pagination handling
   - Error handling (rate limits, auth errors)

## Running Tests

### Run All Tests
```bash
cd /Users/abredykhin/ws/mymoney/supabase/functions/sync-transactions
deno test --allow-env
```

### Run Specific Test File
```bash
deno test --allow-env database.test.ts
deno test --allow-env plaid.test.ts
```

### Run Tests with Coverage
```bash
deno test --allow-env --coverage=coverage
deno coverage coverage
```

### Run Tests in Watch Mode
```bash
deno test --allow-env --watch
```

## Test Structure

All tests follow the **Arrange-Act-Assert (AAA)** pattern:

```typescript
Deno.test('function name - should do something', async () => {
  // Arrange: Set up test data and mocks
  const mockData = {...};
  const mockClient = createMockClient(mockData);

  // Act: Execute the function being tested
  const result = await functionUnderTest(mockClient, params);

  // Assert: Verify the results
  assertEquals(result.property, expectedValue);
});
```

## Mocking Strategy

### Database Operations
Tests mock the Supabase client using a simple mock factory:

```typescript
function createMockSupabaseClient(mockResponses: Record<string, any>) {
  return {
    from: (table: string) => ({
      select: (fields: string) => ({
        eq: (field: string, value: any) => ({
          single: () => mockResponses[`${table}_single`] || { data: null, error: null },
        }),
      }),
      // ... other operations
    }),
  };
}
```

### Plaid API
Tests mock the Plaid client by overriding the global `createPlaidClient` function:

```typescript
function mockCreatePlaidClient(mockClient: any) {
  (globalThis as any).createPlaidClient = () => mockClient;
}
```

## Test Coverage

### Database Operations (database.test.ts)
- ✅ Item fetching (success & error)
- ✅ Account ID mapping (success & empty)
- ✅ Batch upsert accounts (success & empty)
- ✅ Batch upsert transactions (success, skip missing accounts, empty)
- ✅ Batch delete transactions (success & empty)
- ✅ Cursor updates (success & error)
- ✅ RLS compliance (user_id is set)

### Plaid Integration (plaid.test.ts)
- ✅ Transaction updates (single page & multiple pages)
- ✅ Account balances (success)
- ✅ Error handling (rate limits, item login required, network errors)
- ✅ Empty responses
- ✅ Pagination

## Key Test Scenarios

### 1. RLS Compliance Test
Verifies that `user_id` is explicitly set on all transaction records (critical for Row Level Security):

```typescript
Deno.test('batchUpsertTransactions - should set user_id on all transactions (RLS)', async () => {
  // Test implementation captures inserted data and verifies user_id is present
});
```

### 2. Missing Account Handling
Verifies that transactions with missing accounts are skipped gracefully:

```typescript
Deno.test('batchUpsertTransactions - should skip transactions with missing accounts', async () => {
  // Test with account_id that doesn't exist in mapping
});
```

### 3. Pagination Test
Verifies that multi-page Plaid responses are accumulated correctly:

```typescript
Deno.test('fetchTransactionUpdates - should fetch multiple pages of updates', async () => {
  // Mock multiple pages with has_more: true
  // Verify all pages are accumulated
});
```

### 4. Error Handling Tests
Verify proper error handling for:
- Rate limit errors (429)
- Item login required errors
- Network timeouts
- Database errors

## CI/CD Integration

Add to GitHub Actions workflow:

```yaml
- name: Test Edge Functions
  run: |
    cd supabase/functions/sync-transactions
    deno test --allow-env --coverage=coverage
    deno coverage coverage --lcov > coverage.lcov
```

## Performance Benchmarks

You can add performance benchmarks using Deno's bench API:

```typescript
Deno.bench('batchUpsertTransactions with 300 transactions', async () => {
  // Benchmark batch upsert with 300 transactions
});
```

## Next Steps

1. **Add Integration Tests**: Test the full webhook → sync flow
2. **Add E2E Tests**: Test with real (sandboxed) Plaid data
3. **Add Performance Tests**: Verify batch operations meet timing requirements
4. **Add Snapshot Tests**: Verify SQL query generation

## Troubleshooting

### Tests fail with "Module not found"
Ensure you're running tests from the correct directory or use absolute imports.

### Tests hang indefinitely
Check for unresolved promises or missing mock implementations.

### Mock client not working
Verify the mock structure matches the actual client API shape.

## Additional Resources

- [Deno Testing Documentation](https://deno.land/manual/testing)
- [Deno Assertions](https://deno.land/std/assert)
- [Supabase Edge Functions Testing](https://supabase.com/docs/guides/functions/unit-test)
