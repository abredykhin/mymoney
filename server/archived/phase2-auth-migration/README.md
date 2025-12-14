# Phase 2 Auth Migration - Archived Files

**Date Archived**: December 13, 2024
**Reason**: Migration from legacy username/password authentication to Supabase Auth (Sign in with Apple)

## Overview

This directory contains legacy authentication code that was replaced during the Supabase migration (Phase 2). These files are kept for reference but are no longer used in the application.

## Archived Files

### Controllers (from `/server/controllers/`)
- **users.js** - Legacy user registration and login controller
  - `registerUser()` - Created users with bcrypt-hashed passwords
  - `loginUser()` - Validated credentials and returned user
  - `debugChangePassword()` - Debug endpoint for password changes

- **sessions.js** - Legacy session management controller (if existed)

### Routes (from `/server/routes/`)
- **auth.js** - Legacy authentication routes
  - `POST /users` - User registration
  - `POST /users/login` - User login

### Database Queries (from `/server/db/queries/`)
- **users.js** - Database queries for users_table
  - `createUser()` - Insert user with hashed password
  - `retrieveUserByUsername()` - Lookup user by username
  - `updateUserPassword()` - Update password hash
  - Related queries for user management

- **sessions.js** - Database queries for sessions_table (if existed)
  - Session token management
  - Session validation

### Tests (from `/server/tests/unit/db/queries/`)
- **users.test.js** - Unit tests for legacy user queries

## What Replaced This Code?

### iOS Client
**Old**: Username/password → Legacy backend → Session token
```swift
// OLD (deprecated)
userAccount.signIn(email: email, password: password)
```

**New**: Sign in with Apple → Supabase Auth → JWT token
```swift
// NEW (current)
SignInWithAppleCoordinator().signInWithApple()
// Automatically handled by Supabase Auth SDK
```

Key files:
- `ios/Bablo/Bablo/Util/SupabaseManager.swift`
- `ios/Bablo/Bablo/UI/Auth/SignInWithAppleCoordinator.swift`
- `ios/Bablo/Bablo/UI/Auth/WelcomeView.swift`

### Backend
**Old**: Custom auth middleware, session validation, bcrypt
**New**: Supabase Auth (handled by Supabase), JWT validation

Edge Functions now use Supabase Auth:
```typescript
// Get authenticated user from JWT
const { data: { user } } = await supabase.auth.getUser();
```

## Migration Notes

### User Data Migration
- **NOT REQUIRED**: Only test accounts existed in legacy database
- New users authenticate via Sign in with Apple
- User data stored in `auth.users` (managed by Supabase)
- Profile data linked via trigger on signup

### Backward Compatibility
The iOS app still supports legacy users during migration period:
- `UserAccount.swift` checks for both Supabase session and legacy credentials
- Legacy login method marked as `@deprecated`
- Fallback removed after all test users migrated to Supabase

### Database Schema Changes
Legacy tables no longer used:
- `users_table` - Replaced by `auth.users` (Supabase)
- `sessions_table` - Replaced by JWT tokens (Supabase)

New tables:
- `profiles` - User profile data, linked to `auth.users` via trigger

## Security Improvements

### Old (Legacy)
- Passwords hashed with bcrypt ✅
- Session tokens stored in database
- Manual session expiration logic
- Custom authentication middleware

### New (Supabase Auth)
- No password storage (Sign in with Apple) ✅
- JWT tokens (short-lived, auto-refresh) ✅
- Industry-standard OAuth 2.0 flow ✅
- Built-in security best practices ✅
- Automatic token rotation ✅

## Related Documentation

- **Migration Plan**: `/SUPABASE.md` (Phase 2: Authentication Replacement)
- **Project Guide**: `/CLAUDE.md` (Supabase Migration section)
- **iOS Implementation**: Search for "Supabase Migration - Phase 2" comments in iOS code

## Restoration (If Needed)

If you need to temporarily restore this code:

1. Copy files back to their original locations
2. Update `/server/routes/index.js` to re-import controllers
3. Ensure database tables (`users_table`, `sessions_table`) exist
4. Update iOS app to use legacy auth methods

**Note**: This should only be done for emergency rollback scenarios.

## Cleanup Timeline

- **December 2024**: Files archived (this directory created)
- **Target: January 2025**: Verify no legacy users remain
- **Target: February 2025**: Consider deleting this directory permanently

---

**Questions?** See `/SUPABASE.md` Phase 2 section for detailed migration documentation.
