## 6. Error Handling & Rate Limits

### 6.1 Plaid API Rate Limits

**Production Limits:**
- `/transactions/sync`: **50 requests per Item per minute**, 2,500 per client per minute
- `/transactions/get`: **30 requests per Item per minute**, 20,000 per client per minute
- `/transactions/recurring/get`: **Uses same rate limits as /transactions/sync**

**Error Handling Strategy:**

```typescript
/**
 * Retry logic with exponential backoff for rate limit errors
 */
async function callPlaidWithRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  baseDelay: number = 1000
): Promise<T> {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error: any) {
      // Check for rate limit error (HTTP 429)
      if (error.response?.status === 429) {
        if (attempt === maxRetries) {
          throw new Error(`Rate limit exceeded after ${maxRetries} retries`);
        }

        // Exponential backoff: 1s, 2s, 4s, 8s...
        const delay = baseDelay * Math.pow(2, attempt);
        console.warn(`⚠️ Rate limited, retrying in ${delay}ms (attempt ${attempt + 1}/${maxRetries})`);
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }

      // Check for invalid access token (ITEM_LOGIN_REQUIRED)
      if (error.response?.data?.error_code === 'ITEM_LOGIN_REQUIRED') {
        console.error('❌ Item requires re-authentication');
        // Mark item as requiring user action
        await markItemAsNeedsReauth(error.item_id);
        throw new Error('Item requires re-authentication');
      }

      // Check for network/timeout errors
      if (error.code === 'ETIMEDOUT' || error.code === 'ECONNREFUSED') {
        if (attempt === maxRetries) {
          throw new Error(`Network error after ${maxRetries} retries: ${error.code}`);
        }
        const delay = baseDelay * Math.pow(2, attempt);
        console.warn(`⚠️ Network error, retrying in ${delay}ms`);
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }

      // All other errors - don't retry
      throw error;
    }
  }

  throw new Error('Unexpected retry loop exit');
}

/**
 * Mark item as needing reauth
 */
async function markItemAsNeedsReauth(itemId: string) {
  const supabase = createSupabaseClient();
  await supabase
    .from('items_table')
    .update({
      status: 'NEEDS_REAUTH',
      updated_at: new Date().toISOString()
    })
    .eq('plaid_item_id', itemId);
}
```

**Usage in Edge Functions:**

```typescript
// In sync-recurring-transactions
const response = await callPlaidWithRetry(() =>
  plaidClient.transactionsRecurringGet({
    access_token: item.plaid_access_token
  })
);

// In sync-transactions
const response = await callPlaidWithRetry(() =>
  plaidClient.transactionsSync({
    access_token: item.plaid_access_token,
    cursor: item.transactions_cursor,
    count: 500
  })
);
```

### 6.2 Swift SDK Error Handling

**IMPORTANT:** The Supabase Swift SDK only has `.single()`, NOT `.maybeSingle()`.

**Correct error handling pattern:**

```swift
// Option 1: Expect single result, handle error
do {
    let stream = try await supabase
        .from("recurring_streams_table")
        .select()
        .eq("id", streamId)
        .single()
        .execute()
        .value
    // Use stream
} catch {
    // Handle "no rows returned" or "multiple rows returned" error
    print("Error fetching stream: \(error)")
}

// Option 2: Use limit(1) and check array
let response = try await supabase
    .from("recurring_streams_table")
    .select()
    .eq("id", streamId)
    .limit(1)
    .execute()
    .value

if let streams = response as? [[String: Any]], let first = streams.first {
    // Use first stream
} else {
    // No results
}
```
