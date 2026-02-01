## 9. Remove Gemini AI Budget Analysis

### 9.1 Delete Edge Function
```bash
rm -rf supabase/functions/gemini-budget-analysis
```

### 9.2 Drop Legacy Table
```sql
-- Run after confirming recurring_streams_table is working
DROP TABLE IF EXISTS budget_items_table CASCADE;
```

### 9.3 Remove Gemini API Key
Remove `GEMINI_API_KEY` from Supabase Edge Function secrets.

### 9.4 Remove Gemini Trigger from sync-transactions

In `/supabase/functions/sync-transactions/index.ts`, remove this code block:

```typescript
// REMOVE THIS:
const isFirstSync = !item.transactions_cursor;
if (isFirstSync || added.length > 50) {
  if (ctx && typeof ctx.waitUntil === 'function') {
    ctx.waitUntil(triggerBudgetAnalysis(item.user_id as string));
  } else {
    triggerBudgetAnalysis(item.user_id as string).catch(err =>
      console.error('Budget analysis trigger failed:', err)
    );
  }
}
```

The recurring sync now handles what Gemini was doing.
Remove `GEMINI_API_KEY` from Supabase Edge Function secrets.
