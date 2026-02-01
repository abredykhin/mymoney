## 12. User Experience Improvements

### 12.1 Transparency
- Show users which transactions are marked as recurring
- Display "Recurring" badge on transaction rows
- Show source: "Detected by Plaid" vs "Marked by you"

### 12.2 Override Flow
```
1. User sees a subscription charge marked as variable spend
2. User taps transaction → "Mark as Recurring"
3. Backend finds the stream this transaction belongs to
4. Sets `user_marked_recurring = true` on stream
5. All transactions in that stream update to `is_recurring = true`
6. Budget recalculates instantly
```

### 12.3 Notifications
- Alert user when new recurring streams are detected
- Notify when recurring stream becomes inactive
- Suggest reviewing recurring expenses quarterly
