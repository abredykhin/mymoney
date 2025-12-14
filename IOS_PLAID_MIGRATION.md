# iOS Plaid Link Migration - Phase 3

**Date**: December 12, 2025
**Status**: Link Token migrated to Supabase Edge Functions ✅

This document covers the iOS app changes to use Supabase Edge Functions for Plaid integration.

---

## 🎯 What Was Migrated

### Route Migrated:
- **Legacy**: `POST /link-token` (Node.js backend)
- **New**: `plaid-link-token` (Supabase Edge Function)

### iOS Changes:
1. ✅ Created **`PlaidService.swift`** - Service layer for Plaid operations
2. ✅ Updated **`LinkButtonView.swift`** - Use PlaidService instead of OpenAPI client
3. ✅ Added loading states and error handling

---

## 📁 Files Changed

### New Files:
```
ios/Bablo/Bablo/Services/
└── PlaidService.swift          ✨ NEW
```

### Modified Files:
```
ios/Bablo/Bablo/Link/
└── LinkButtonView.swift        📝 UPDATED
```

---

## 🔧 What Changed in Detail

### 1. PlaidService.swift (NEW)

A dedicated service for all Plaid-related operations:

**Key Methods:**

```swift
class PlaidService: ObservableObject {
    /// Create link token for new bank connection
    func createLinkToken(itemId: Int? = nil) async throws -> String

    /// Save new item after Plaid Link success (legacy endpoint for now)
    func saveNewItem(publicToken: String, institutionId: String) async throws

    /// Update existing item (re-authenticate)
    func updateItem(itemId: Int) async throws -> String
}
```

**Features:**
- ✅ Uses Supabase Functions SDK
- ✅ Proper error handling with custom error types
- ✅ Comprehensive logging
- ✅ Observable for SwiftUI integration
- ✅ Supports both new link and update modes

**Example Usage:**

```swift
let plaidService = PlaidService()

// Create link token for new connection
let linkToken = try await plaidService.createLinkToken()

// Create link token for updating existing item
let updateToken = try await plaidService.updateItem(itemId: 123)

// Save item after successful link
try await plaidService.saveNewItem(
    publicToken: "public-token-from-plaid",
    institutionId: "ins_123"
)
```

---

### 2. LinkButtonView.swift (UPDATED)

Updated to use PlaidService instead of calling OpenAPI client directly.

**Before:**
```swift
// Called OpenAPI client directly
let response = try await userAccount.client?.getLinkToken()

// Handled response with switch statement
switch response {
case .ok(okResponse: let okResponse):
    switch okResponse.body {
    case .json(let json):
        // Process link token
    }
// ... more cases
}
```

**After:**
```swift
// Use PlaidService
let linkToken = try await plaidService.createLinkToken()

// Simpler, cleaner code
let config = try await generateLinkConfig(linkToken: linkToken)
// ... create Plaid handler
```

**New Features:**
- ✅ Loading state with spinner
- ✅ Error alerts with user-friendly messages
- ✅ Better UX - button disabled while loading
- ✅ Async/await throughout (cleaner than callbacks)

**UI Improvements:**

| State | Before | After |
|-------|--------|-------|
| **Idle** | "Link new account" button | Same |
| **Loading** | No indication | Spinner + "Loading..." |
| **Error** | Silent failure | Alert with error message |
| **Success** | Shows Plaid Link | Same |

---

## 🎨 User Experience Improvements

### Loading State
When user taps "Link new account":
1. Button shows spinner and "Loading..." text
2. Button is disabled (prevents double-tap)
3. Network request to Supabase Edge Function
4. Plaid Link appears when ready

### Error Handling
If something goes wrong:
- User sees alert with friendly error message
- Error is logged for debugging
- User can dismiss and try again

### Better Feedback
- Logs show each step of the process
- Easier to debug issues
- Better visibility into what's happening

---

## 🔄 Migration Status

### ✅ Completed:
- [x] `PlaidService` created with link token method
- [x] `LinkButtonView` updated to use PlaidService
- [x] Loading states added
- [x] Error handling improved
- [x] Logging enhanced

### ⏳ Still Using Legacy Backend:
- [ ] `saveNewItem()` - Still uses OpenAPI client
  - **Why**: Needs separate Edge Function for token exchange
  - **When**: Phase 3 next steps
  - **Impact**: Low - only affects new connections

### 🚀 Future Migrations:
- [ ] Create `save-item` Edge Function
- [ ] Create `refresh-accounts` Edge Function
- [ ] Create `delete-item` Edge Function
- [ ] Migrate webhook handling
- [ ] Remove OpenAPI client dependency

---

## 🧪 Testing the Changes

### Prerequisites:
1. ✅ Supabase Edge Function deployed:
   ```bash
   cd supabase
   supabase functions deploy plaid-link-token
   ```

2. ✅ Environment secrets set:
   ```bash
   supabase secrets set PLAID_CLIENT_ID=your_id
   supabase secrets set PLAID_SECRET=your_secret
   supabase secrets set PLAID_ENV=sandbox
   ```

3. ✅ iOS app has Supabase configured (from Phase 2)

### Test Scenarios:

#### 1. Add New Bank Account

**Steps:**
1. Open iOS app
2. Sign in with Apple (Supabase Auth)
3. Tap "Link new account" button
4. Observe loading spinner
5. Plaid Link should open
6. Complete bank connection flow

**Expected Behavior:**
- ✅ Button shows "Loading..." with spinner
- ✅ Plaid Link opens after 1-3 seconds
- ✅ No errors in Xcode console
- ✅ After success, new bank appears in app

**If It Fails:**
- Check Xcode console for error logs
- Verify Supabase function is deployed
- Check Supabase dashboard logs
- Ensure user is authenticated

#### 2. Error Handling

**Simulate errors** to test error handling:

**No Internet Connection:**
1. Turn off WiFi/cellular
2. Tap "Link new account"
3. Should see error alert

**Invalid Credentials:**
1. Set wrong PLAID_SECRET in Supabase
2. Tap "Link new account"
3. Should see error alert with Plaid error

**Authentication Failure:**
1. Sign out of Supabase
2. Try to link account
3. Should be prompted to sign in

#### 3. Loading States

**Test loading indicators:**
1. Tap "Link new account"
2. Button should show spinner immediately
3. Button should be disabled
4. Can't tap button again while loading

---

## 🐛 Troubleshooting

### "Failed to load link token" Error

**Possible Causes:**
1. Edge Function not deployed
2. Plaid credentials not set
3. User not authenticated
4. Network issue

**Debug Steps:**
```swift
// Check Xcode console for:
"PlaidService: Creating link token"
"PlaidService: Received response from plaid-link-token function"
"PlaidService: Successfully created link token"

// If you see errors like:
"Error creating link token: ..."
// Check Supabase dashboard logs
```

**Solutions:**
- Verify Edge Function deployed: `supabase functions list`
- Check secrets: `supabase secrets list`
- Test function directly with curl (see EDGE_FUNCTION_DEPLOYMENT.md)
- Check Supabase dashboard → Edge Functions → Logs

---

### Plaid Link Doesn't Open

**Possible Causes:**
1. Invalid link token
2. Plaid SDK not properly configured
3. Handler creation failed

**Debug Steps:**
```swift
// Look for this in logs:
"LinkController initialized successfully"

// If you see:
"Failed to create Plaid handler: ..."
// The link token might be invalid
```

**Solutions:**
- Verify link token format (should start with "link-")
- Check Plaid dashboard for errors
- Ensure Plaid SDK is properly installed
- Try creating new link token

---

### "Missing Client" Error in saveNewItem

**Cause:** UserAccount.client is nil

**Why:** This happens if user isn't properly authenticated or client not initialized

**Solution:**
- This is the legacy client - still needed for saveNewItem
- Ensure user is signed in
- Check UserAccount initialization

**Future:** Will be fixed when saveNewItem migrated to Edge Function

---

## 📊 Code Comparison

### Before (Legacy):

```swift
// LinkButtonView.swift - OLD
.task {
    do {
        let response = try await userAccount.client?.getLinkToken()

        switch response {
        case .ok(okResponse: let okResponse):
            switch okResponse.body {
            case .json(let json):
                Logger.i("Received OK response for Link token")
                let config = try await generateLinkConfig(linkToken: json.link_token)
                let handler = Plaid.create(config)
                switch handler {
                case .success(let handler):
                    self.linkController = LinkController(handler: handler)
                    Logger.i("LinkController initialized")
                case .failure(let error):
                    Logger.e("Failed to init Plaid: \(error)")
                }
            }
        case .unauthorized:
            userAccount.signOut()
        case .undocumented(statusCode: let statusCode, _):
            Logger.e("Recieved error from server. statusCode = \(statusCode)")
        case .none:
            Logger.e("FAIL")
        }
    } catch {
        Logger.e("Failed to init Plaid: \(error)")
    }
}
```

**Issues:**
- ❌ No loading state
- ❌ Errors not shown to user
- ❌ Complex nested switch statements
- ❌ Couples view to network client
- ❌ Hard to test
- ❌ Runs on view appearance (may not be desired)

---

### After (Supabase):

```swift
// LinkButtonView.swift - NEW
Button {
    Task {
        await loadLinkToken()
    }
} label: {
    HStack {
        if isLoadingLinkToken {
            ProgressView()
        }
        Text(isLoadingLinkToken ? "Loading..." : "Link new account")
    }
}
.disabled(isLoadingLinkToken)

// ...

private func loadLinkToken() async {
    isLoadingLinkToken = true
    defer { isLoadingLinkToken = false }

    do {
        let linkToken = try await plaidService.createLinkToken()
        let config = try await generateLinkConfig(linkToken: linkToken)

        let handler = Plaid.create(config)
        switch handler {
        case .success(let handler):
            self.linkController = LinkController(handler: handler)
            shouldPresentLink = true
        case .failure(let error):
            errorMessage = "Failed to initialize Plaid Link"
            showError = true
        }
    } catch {
        errorMessage = "Failed to load link token"
        showError = true
    }
}
```

**Benefits:**
- ✅ Clear loading state
- ✅ User-friendly error messages
- ✅ Cleaner code with async/await
- ✅ Separation of concerns (PlaidService)
- ✅ Easier to test
- ✅ Triggered by user action

---

## 🎯 Architecture Benefits

### Separation of Concerns

**Before:**
```
LinkButtonView
    ↓
OpenAPI Client → Node.js Backend → Plaid API
```

**After:**
```
LinkButtonView
    ↓
PlaidService
    ↓
Supabase Functions → Plaid API
```

**Benefits:**
- ✅ View only handles UI
- ✅ Service handles business logic
- ✅ Easy to swap implementations
- ✅ Testable in isolation

---

### Error Handling

**Before:**
- Errors logged to console
- User sees nothing
- Hard to debug

**After:**
- Errors shown to user
- Detailed logs for debugging
- Typed errors for specific handling

---

### State Management

**Before:**
- No loading state
- Button always enabled
- Can tap multiple times

**After:**
- Clear loading indication
- Button disabled while loading
- Prevents double-taps

---

## 📱 Screenshots / UI Flow

### 1. Initial State
```
┌─────────────────────────────┐
│                             │
│   [Link new account]        │
│                             │
└─────────────────────────────┘
```

### 2. Loading State
```
┌─────────────────────────────┐
│                             │
│   [◯ Loading...]            │
│                             │
└─────────────────────────────┘
```

### 3. Error State
```
┌─────────────────────────────┐
│        ⚠️ Error              │
│                             │
│  Failed to load link token  │
│                             │
│          [OK]               │
└─────────────────────────────┘
```

### 4. Success State
```
┌─────────────────────────────┐
│                             │
│   [Plaid Link Interface]    │
│                             │
└─────────────────────────────┘
```

---

## ✅ Verification Checklist

Test these scenarios before considering migration complete:

- [ ] **Fresh Install**
  - [ ] Install app
  - [ ] Sign in with Apple
  - [ ] Link bank account successfully

- [ ] **Existing User**
  - [ ] User with legacy credentials can still link
  - [ ] Migrated user (Supabase Auth) can link

- [ ] **Error Scenarios**
  - [ ] No internet - shows error
  - [ ] Invalid credentials - shows error
  - [ ] User not authenticated - handled gracefully

- [ ] **UI/UX**
  - [ ] Loading spinner appears
  - [ ] Button disables during load
  - [ ] Error alerts work
  - [ ] Plaid Link opens correctly

- [ ] **End-to-End**
  - [ ] Complete bank connection
  - [ ] New accounts appear in app
  - [ ] Transactions sync correctly

---

## 🚀 Deployment

### For Testing (Sandbox):
1. Deploy Edge Function with sandbox Plaid credentials
2. Build iOS app in debug mode
3. Test with Plaid sandbox banks

### For Production:
1. Deploy Edge Function with production Plaid credentials
   ```bash
   supabase secrets set PLAID_ENV=production
   supabase secrets set PLAID_SECRET=your_production_secret
   ```
2. Build iOS app in release mode
3. Submit to TestFlight
4. Test thoroughly before App Store release

---

## 📚 Related Documentation

- **EDGE_FUNCTION_DEPLOYMENT.md** - How to deploy Edge Functions
- **IOS_APPLE_SIGNIN_SETUP.md** - iOS Supabase Auth setup
- **SUPABASE.md** - Full migration plan
- **Phase 2 Summary** - Authentication migration

---

## 🎉 Success!

The link token route has been successfully migrated from the legacy Node.js backend to Supabase Edge Functions!

**Key Achievements:**
- ✅ No more dependency on legacy backend for link tokens
- ✅ Better error handling and user feedback
- ✅ Cleaner, more maintainable code
- ✅ Ready for further Edge Function migrations

**Next Steps:**
- Migrate remaining Plaid endpoints (webhook, save item, etc.)
- Remove OpenAPI client dependency completely
- Decommission legacy backend

Happy linking! 🎊
