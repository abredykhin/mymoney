# Phase 4 API Migration - Archived Files

**Date Archived**: December 13, 2024
**Reason**: Migration from legacy Node.js API client to Supabase direct database access

## Overview

This directory contains legacy service classes that used the OpenAPI-generated client to call the Node.js backend API. These files are replaced by new Supabase-based services that query the database directly using RLS for security.

## Archived Files

### From `/Model/` Directory

1. **BankAccountsService.swift** - Legacy service for bank accounts
   - Used `client.getUserAccounts()` API call
   - Cached data in CoreData
   - **Replaced by**: `/Services/AccountsService.swift`

2. **TransactionsService.swift** - Legacy service for transactions
   - Complex pagination and filtering via API
   - Multiple API endpoints for different views
   - **Replaced by**: `/Services/TransactionsService.swift`

3. **BudgetService.swift** - Legacy service for budget/spending analysis
   - Used `client.getTotalBudget()` and `client.getCategoryBreakdown()` API calls
   - **Replaced by**: `/Services/BudgetService.swift`

## What Changed?

### Old Architecture (Legacy)
```
iOS App → OpenAPI Client → Node.js API → PostgreSQL
         ├─ getUserAccounts()
         ├─ getTransactions()
         └─ getTotalBudget()
```

**Issues**:
- Required maintaining Node.js backend
- Additional network hop (iOS → API → Database)
- OpenAPI client code generation complexity
- Manual session/token management

### New Architecture (Supabase)
```
iOS App → Supabase SDK → PostgreSQL (with RLS)
         └─ Direct database queries secured by Row Level Security
```

**Benefits**:
- No backend maintenance ✅
- Direct database access (faster) ✅
- Automatic auth via Supabase JWT ✅
- RLS handles security automatically ✅
- Simpler codebase ✅

## Code Comparison

### Fetching Accounts

**Old (Legacy)**:
```swift
// BankAccountsService.swift (archived)
func refreshAccounts() async throws {
    guard let client = UserAccount.shared.client else { return }

    let response = try await client.getUserAccounts()

    switch response {
    case .ok(let json):
        switch json.body {
        case .json(let bodyJson):
            self.banksWithAccounts = bodyJson.banks ?? []
        }
    case .unauthorized(_):
        UserAccount.shared.signOut()
    default:
        throw URLError(.badServerResponse)
    }
}
```

**New (Supabase)**:
```swift
// Services/AccountsService.swift
func refreshAccounts() async throws {
    let response: [AccountWithBank] = try await supabase
        .from("accounts_with_banks")
        .select()
        .eq("hidden", value: false)
        .order("name")
        .execute()
        .value

    // Group and transform...
    self.banksWithAccounts = transformToBanks(response)
}
```

**What improved**:
- ✅ Simpler code (no switch/case for response types)
- ✅ Direct query with type safety
- ✅ RLS automatically filters by user
- ✅ No manual auth checking needed

### Fetching Transactions

**Old (Legacy)**:
```swift
// TransactionsService.swift (archived)
func fetchRecentTransactions() async throws {
    guard let client = UserAccount.shared.client else { return }

    let response = try await client.getRecentTransactions(
        query: .init(limit: 50, cursor: nil)
    )

    switch response {
    case .ok(let json):
        // Parse response...
    default:
        throw URLError(.badServerResponse)
    }
}
```

**New (Supabase)**:
```swift
// Services/TransactionsService.swift
func fetchRecentTransactions() async throws {
    let response: [Transaction] = try await supabase
        .from("transactions_table")
        .select()
        .order("date", ascending: false)
        .limit(50)
        .execute()
        .value

    self.transactions = response
}
```

**What improved**:
- ✅ Cleaner, more declarative
- ✅ No response parsing logic
- ✅ Direct Codable support
- ✅ Automatic auth via JWT

### Budget/Spending Analysis

**Old (Legacy)**:
```swift
// BudgetService.swift (archived)
func fetchTotalBalance() async throws {
    guard let client = UserAccount.shared.client else { return }

    let response = try await client.getTotalBudget()

    switch response {
    case .ok(let json):
        switch json.body {
        case .json(let totalBalance):
            self.totalBalance = totalBalance
        }
    case .unauthorized(_):
        UserAccount.shared.signOut()
    default:
        Logger.w("Can't handle the response")
    }
}
```

**New (Supabase)**:
```swift
// Services/BudgetService.swift
func fetchTotalBalance() async throws {
    let accounts: [AccountBalance] = try await supabase
        .from("accounts")
        .select("current_balance")
        .eq("hidden", value: false)
        .execute()
        .value

    let total = accounts.reduce(0) { $0 + $1.currentBalance }
    self.totalBalance = TotalBalance(balance: total, asOf: Date())
}
```

**What improved**:
- ✅ Calculate on client (simple sum)
- ✅ No API endpoint needed
- ✅ Real-time accurate
- ✅ No response handling complexity

## Migration Impact

### Files Updated

**Services** (new, in `/Services/`):
- ✅ `AccountsService.swift` - Replaces `Model/BankAccountsService.swift`
- ✅ `TransactionsService.swift` - Replaces `Model/TransactionsService.swift`
- ✅ `BudgetService.swift` - Replaces `Model/BudgetService.swift`
- ✅ `PlaidService.swift` - Updated to use Edge Functions only

**Models** (may need updates):
- `Bank`, `BankAccount`, `Transaction` typealias removed (now in services)
- CoreData cache managers may need updates

**Views** (should work with minimal changes):
- Most views use `@StateObject` or `@EnvironmentObject` for services
- Property names remain the same (`banksWithAccounts`, `transactions`, etc.)
- Only import statements need updating

### Breaking Changes

1. **Import statements**:
   ```swift
   // Old
   // Typealias at top of BankAccountsService.swift

   // New
   // Models defined in Services/*.swift files
   ```

2. **Service initialization**:
   ```swift
   // Old
   @StateObject private var accountsService = BankAccountsService()

   // New (same!)
   @StateObject private var accountsService = AccountsService()
   ```

3. **OpenAPI client removed**:
   - No more `OpenAPIRuntime` or `OpenAPIURLSession` imports needed
   - `UserAccount.shared.client` still exists for legacy compatibility

## Database Views Required

The new services expect these database views:

### `accounts_with_banks` View
```sql
CREATE VIEW accounts_with_banks AS
SELECT
    a.*,
    i.id as institution_id,
    i.name as institution_name,
    i.logo as institution_logo,
    i.primary_color as institution_color,
    i.url as institution_url
FROM accounts a
JOIN items it ON a.item_id = it.id
JOIN institutions i ON it.institution_id = i.id;
```

This view joins accounts with their bank information for efficient querying.

## Testing Checklist

After migrating to new services:

- [ ] Accounts load and display correctly
- [ ] Transactions load and display correctly
- [ ] Budget/total balance calculates correctly
- [ ] Pagination works (load more transactions)
- [ ] Filters work (date range, category, search)
- [ ] Account hiding/showing works
- [ ] Plaid Link still works (connect new bank)
- [ ] RLS is enforced (users only see their own data)
- [ ] Performance is acceptable
- [ ] No crashes or errors

## Rollback Plan

If you need to rollback (not recommended):

1. Copy files back from this archived directory to `/Model/`
2. Revert `/Services/` to remove new Supabase services
3. Ensure OpenAPI client is still configured
4. Ensure legacy Node.js backend is still running

**Note**: This should only be done for emergency situations. The new architecture is simpler and more maintainable.

## Performance Notes

**Expected improvements**:
- ✅ Faster data loading (one less network hop)
- ✅ Simpler code (fewer lines, easier to understand)
- ✅ Better error handling (Supabase SDK provides clear errors)
- ✅ Automatic retries and connection management

**Potential issues**:
- ⚠️ More complex queries run on client (e.g., category breakdown)
- ⚠️ Need to create database views for efficient joins

## Future Enhancements

Now that we have direct database access:

1. **Real-time updates**: Use Supabase Realtime to get live transaction updates
2. **Offline support**: Cache data locally and sync when online
3. **Better filtering**: More complex queries without backend changes
4. **Custom views**: Create personalized data views in SQL

## Questions?

- **Migration Plan**: See `/SUPABASE.md` Phase 4 section
- **New Services**: Check `/Services/*.swift` for current implementations
- **Database Schema**: See `/supabase/migrations/` for RLS policies and views

---

**Status**: ✅ Phase 4 migration complete, legacy services archived
