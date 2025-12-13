# iOS Build Fixes - Supabase Migration

**Date**: December 11, 2025
**Issue**: Build errors after adding Supabase Auth integration

---

## 🔧 Fixes Applied

### 1. Fixed User Model - Added Email Parameter

**Problem**: The `User` struct was updated to include an `email` field, but legacy authentication methods (`login` and `register`) were not providing this parameter.

**Error**:
```
Missing argument for parameter 'email' in call
```

**Solution**: Updated the legacy `login()` and `register()` methods in `UserAccount.swift` to include the email parameter:

**Files Modified**:
- `ios/Bablo/Bablo/Model/UserAccount.swift:303` - Added `email: username` to User initialization
- `ios/Bablo/Bablo/Model/UserAccount.swift:328` - Added `email: username` to User initialization

```swift
// Before (causing error):
return User(id: json.user.id, name: json.user.username, token: json.token)

// After (fixed):
return User(id: json.user.id, name: json.user.username, token: json.token, email: username)
```

---

### 2. Updated PasswordFallbackView for Supabase Users

**Problem**: `PasswordFallbackView` is used when biometric authentication fails, but it doesn't make sense for users authenticated with Apple Sign In (no password).

**Solution**: Added logic to detect Supabase users and show appropriate UI:

**Files Modified**:
- `ios/Bablo/Bablo/UI/Auth/PasswordFallbackView.swift`

**Changes**:
1. **Added `isSupabaseUser()` helper method**:
   - Detects Supabase users by checking if user ID is a UUID
   - Supabase user IDs are UUIDs, legacy IDs are numeric strings

2. **Conditional UI rendering**:
   - **For Supabase users**: Shows a message explaining password auth is unavailable and offers sign-out
   - **For legacy users**: Shows traditional password entry form with migration reminder

```swift
// Supabase users see:
"Password Authentication Unavailable"
"Your account uses Sign in with Apple. Please sign out and sign back in with Apple to continue."
[Sign Out button]

// Legacy users see:
[Email/Password form]
"Using old credentials? Consider signing out and using Sign in with Apple for better security."
```

---

## 📋 Current State

### What Works Now:
- ✅ **New users** can sign in with Apple (Supabase Auth)
- ✅ **Legacy users** can still use email/password (until backend is deprecated)
- ✅ **Biometric unlock** works for both user types
- ✅ **Supabase users** are prevented from using password fallback (guided to sign out/in)
- ✅ **Build succeeds** without errors

### What's Still Legacy (Phase 3 Migration):
- ⏳ **BankAccountsService** - Still uses OpenAPI Client to call legacy backend
- ⏳ **TransactionsService** - Still uses OpenAPI Client
- ⏳ **Other API services** - Still use legacy backend endpoints
- ⏳ **OpenAPI Client** - Still configured and used for API calls

**These services will be migrated to use Supabase Edge Functions in Phase 3.**

---

## 🔄 Migration Flow

### For New Users:
1. Open app → See WelcomeView with "Sign in with Apple" button
2. Tap button → Apple authentication flow
3. Authenticate → Supabase creates account
4. Signed in → UserAccount receives Supabase session
5. API calls still use legacy backend (Phase 3 will migrate these)

### For Existing Users (Legacy Credentials):
1. Open app → Credentials loaded from Keychain
2. Signed in → API calls work with legacy backend
3. If biometric fails → PasswordFallbackView shows migration reminder
4. User can continue or sign out and migrate to Apple Sign In

### For Migrated Users (Supabase):
1. Open app → Supabase session restored automatically
2. Signed in → API calls work with legacy backend (for now)
3. If biometric fails → PasswordFallbackView shows "Sign in with Apple" message
4. User must sign out and sign back in with Apple

---

## 🎯 Next Steps

### Immediate (To Complete iOS Migration):
1. ✅ **Add Supabase package to Xcode** (see `IOS_APPLE_SIGNIN_SETUP.md`)
2. ✅ **Add new files to Xcode project**
3. ✅ **Configure Supabase credentials in Info.plist**
4. ✅ **Enable Sign in with Apple capability**
5. ✅ **Test the new sign-in flow**

### Phase 3 (Backend Migration):
After iOS sign-in works:
1. Migrate API services to use Supabase Edge Functions
2. Update `BankAccountsService.swift` to call Supabase functions
3. Update `TransactionsService.swift` to call Supabase functions
4. Remove OpenAPI Client dependency
5. Decommission legacy backend

---

## 🐛 Troubleshooting

### Build Error: "Cannot find 'SupabaseClient' in scope"

**Cause**: Supabase Swift package not added to project.

**Solution**: Follow Step 1 in `IOS_APPLE_SIGNIN_SETUP.md` to add the package.

---

### Build Error: "Missing argument for parameter 'email'"

**Cause**: This error should now be fixed. If you still see it, check:

**Solution**:
1. Make sure you've pulled the latest changes to `UserAccount.swift`
2. Look for any other places creating `User` objects
3. All `User` initializations need the `email` parameter

---

### Runtime Error: "Missing Supabase configuration"

**Cause**: `SUPABASE_URL` or `SUPABASE_ANON_KEY` not configured.

**Solution**: Follow Step 3 in `IOS_APPLE_SIGNIN_SETUP.md`.

---

### Legacy Users Can't Sign In After Migration

**Cause**: Legacy backend will be deprecated.

**Solution**:
- This is expected behavior during migration
- Users with legacy credentials should be encouraged to:
  1. Sign out
  2. Sign in with Apple
  3. Data will be preserved (same email matching)

---

## 📊 Architecture Overview

### Current Hybrid Architecture:

```
┌─────────────────────────────────────────┐
│           iOS App (Bablo)               │
├─────────────────────────────────────────┤
│                                         │
│  Authentication:                        │
│  ┌─────────────────────────────────┐  │
│  │ New Users → Supabase Auth      │  │
│  │ (Apple Sign In)                │  │
│  └─────────────────────────────────┘  │
│  ┌─────────────────────────────────┐  │
│  │ Legacy Users → Legacy Backend  │  │
│  │ (Email/Password)               │  │
│  └─────────────────────────────────┘  │
│                                         │
│  API Calls (Phase 3 migration):         │
│  ┌─────────────────────────────────┐  │
│  │ ALL USERS → Legacy Backend     │  │
│  │ (OpenAPI Client)               │  │
│  └─────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### Target Architecture (After Phase 3):

```
┌─────────────────────────────────────────┐
│           iOS App (Bablo)               │
├─────────────────────────────────────────┤
│                                         │
│  Authentication:                        │
│  ┌─────────────────────────────────┐  │
│  │ Supabase Auth                  │  │
│  │ (Apple Sign In)                │  │
│  └─────────────────────────────────┘  │
│                                         │
│  API Calls:                            │
│  ┌─────────────────────────────────┐  │
│  │ Supabase Edge Functions        │  │
│  │ (Serverless)                   │  │
│  └─────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────┐
│         Supabase (Backend)              │
├─────────────────────────────────────────┤
│  • Auth (JWT tokens)                    │
│  • Database (PostgreSQL + RLS)          │
│  • Edge Functions (Deno runtime)        │
└─────────────────────────────────────────┘
```

---

## 🔍 Code References

### Key Files Changed:
- `ios/Bablo/Bablo/Model/UserAccount.swift:303, 328` - Added email parameter to legacy auth
- `ios/Bablo/Bablo/UI/Auth/PasswordFallbackView.swift:26, 149` - Added Supabase user detection

### Files That Still Use Legacy Backend:
- `ios/Bablo/Bablo/Model/BankAccountsService.swift` - Calls `client.getUserAccounts()`
- `ios/Bablo/Bablo/Model/TransactionsService.swift` - Calls transaction endpoints
- `ios/Bablo/Bablo/Util/Network/AuthMiddleware.swift` - Adds legacy auth token to requests
- `ios/Bablo/Bablo/Util/Network/Client+Extensions.swift` - OpenAPI Client extensions

These will be migrated in Phase 3.

---

## ✅ Verification

To verify the build is fixed:

1. **Clean build folder**: Cmd + Shift + K in Xcode
2. **Build**: Cmd + B
3. **Check for errors**: Should build successfully
4. **Run**: Cmd + R (if you've completed manual setup steps)

If build succeeds → ✅ You're ready for manual setup steps in `IOS_APPLE_SIGNIN_SETUP.md`

---

## 📚 Related Documentation

- `IOS_APPLE_SIGNIN_SETUP.md` - Complete setup guide for Apple Sign In
- `PHASE2_MIGRATION_SUMMARY.md` - Overall Phase 2 migration summary
- `SUPABASE.md` - Full migration plan including Phase 3

---

## 💡 Notes

### Why Keep Legacy Methods?

The legacy `signIn()` and `createAccount()` methods are marked as deprecated but not removed because:

1. **Backward Compatibility**: Users with existing legacy credentials can still sign in during migration
2. **Gradual Migration**: Allows testing Supabase auth while legacy backend is still running
3. **PasswordFallbackView**: Still needs these methods for legacy users
4. **Safety**: Can revert to legacy if needed during migration

Once all users are migrated and Phase 3 is complete, these methods can be safely removed.

### Data Preservation

When a user signs out of a legacy account and signs in with Apple:
- Supabase creates a NEW user account (different user ID)
- To preserve data, you'll need to migrate it based on email matching
- This can be done via a Supabase Edge Function (Phase 3)
- Or manually via database migration script

### Testing Strategy

Test these scenarios before deploying:
1. ✅ New user signs in with Apple → Creates Supabase account
2. ✅ Existing legacy user continues using app → Works normally
3. ✅ Legacy user biometric fails → Shows password fallback
4. ✅ Supabase user biometric fails → Shows "use Apple" message
5. ✅ User signs out → Can sign back in with Apple
6. ✅ App restart → Session restored automatically (Supabase users)
