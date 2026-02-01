## 11. Testing Plan

### Critical Webhook Flow Tests

**Test 1: Historical Sync Completion Detection**
```bash
# Simulate SYNC_UPDATES_AVAILABLE with historical_update_complete: true
curl -X POST 'http://localhost:54321/functions/v1/plaid-webhook' \
  -H "Content-Type: application/json" \
  -d '{ 
    "webhook_type": "TRANSACTIONS",
    "webhook_code": "SYNC_UPDATES_AVAILABLE",
    "item_id": "test-item-123",
    "new_transactions": 150,
    "historical_update_complete": true
  }'

# Verify:
# 1. items_table.historical_sync_complete = TRUE
# 2. sync-recurring-transactions was triggered
# 3. recurring_streams_table populated
```

**Test 2: RECURRING_TRANSACTIONS_UPDATE Webhook**
```bash
# Simulate recurring pattern change notification
curl -X POST 'http://localhost:54321/functions/v1/plaid-webhook' \
  -H "Content-Type: application/json" \
  -d '{ 
    "webhook_type": "TRANSACTIONS",
    "webhook_code": "RECURRING_TRANSACTIONS_UPDATE",
    "item_id": "test-item-123"
  }'

# Verify:
# 1. sync-recurring-transactions was triggered
# 2. recurring_streams_table updated with new patterns
```

**Test 3: Historical Incomplete - Should Not Sync Recurring**
```bash
# Simulate regular sync before historical complete
curl -X POST 'http://localhost:54321/functions/v1/plaid-webhook' \
  -H "Content-Type: application/json" \
  -d '{ 
    "webhook_type": "TRANSACTIONS",
    "webhook_code": "SYNC_UPDATES_AVAILABLE",
    "item_id": "test-item-123",
    "new_transactions": 25,
    "historical_update_complete": false
  }'

# Verify:
# 1. sync-transactions ran
# 2. sync-recurring-transactions was NOT triggered
# 3. items_table.historical_sync_complete still FALSE
```

### 11.1 Unit Tests
- Test frequency-to-monthly conversion logic
- Test user override precedence logic
- Test transaction flag updates
- **Test manual stream pattern extraction logic**
- **Test pattern matching algorithm (substring, case-insensitive)**

### 11.2 Integration Tests
- Test full sync flow with Plaid sandbox
- Test user override persistence
- Test budget recalculation accuracy
- **Test manual stream creation flow**
- **Test manual stream deletion and orphaned transactions**
- **Test conflict resolution between Plaid and manual streams**

### 11.3 End-to-End Tests
- Link sandbox account with 180 days of transactions
- Verify recurring streams detected correctly
- Manually override a stream
- Verify budget updates correctly
- Verify `variable_transactions` view excludes correctly
- **Create manual stream from transaction not detected by Plaid**
- **Verify manual stream matches all similar transactions**
- **Delete manual stream and verify transactions become variable again**
- **Verify manual stream with 2 occurrences affects budget correctly**
