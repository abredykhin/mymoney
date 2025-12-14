# iOS Authentication Testing Guide

**Phase 2 Complete!** This guide helps you test the Supabase Auth integration (Sign in with Apple).

## Prerequisites

### 1. Supabase Configuration
Ensure your iOS project has the Supabase credentials configured:

```swift
// These should be set in your build settings or Config.swift
SUPABASE_URL = "https://[your-project].supabase.co"
SUPABASE_ANON_KEY = "eyJhbGc..." // Your anon key
```

Check: `ios/Bablo/Bablo/Util/SupabaseManager.swift:22`

### 2. Apple Sign In Capability
Ensure "Sign in with Apple" is enabled in Xcode:
1. Select your target → Signing & Capabilities
2. Add "Sign in with Apple" capability
3. Verify your bundle ID is registered in Apple Developer Portal

### 3. Supabase Dashboard Configuration
1. Go to Authentication → Providers → Apple
2. Enable Apple provider
3. Configure Bundle ID and Services ID
4. Add redirect URL: `[your-bundle-id]://auth/callback`

## Test Scenarios

### Test 1: First-Time Sign In (New User) ✨

**Goal**: Verify a new user can sign in and create an account

**Steps**:
1. **Launch app** (use a device or simulator WITHOUT an existing signed-in user)
2. **Expect**: WelcomeView appears with "Sign in with Apple" button
3. **Tap** "Sign in with Apple" button
4. **Apple Sheet Appears**: Choose an Apple ID
5. **First Sign In**: Apple asks to share email and name
6. **Expect**:
   - Sign in succeeds
   - App shows ContentView (main app)
   - User is authenticated
   - If biometrics available, shows biometric enrollment prompt

**What to Check**:
- ✅ No errors in console
- ✅ Logs show: "SignInWithAppleCoordinator: Successfully signed in to Supabase"
- ✅ User ID is logged (UUID format)
- ✅ App transitions to main content

**Troubleshooting**:
- **"Invalid credential type"** → Check Apple capability in Xcode
- **"Missing nonce"** → This shouldn't happen (file a bug)
- **"Unable to fetch identity token"** → Try again, may be temporary Apple issue

---

### Test 2: Returning User Sign In ✅

**Goal**: Verify existing users can sign in seamlessly

**Steps**:
1. **Kill app completely** (swipe up from app switcher)
2. **Relaunch app**
3. **Expect**: Either
   - **Option A**: User automatically signed in (session persisted) → Shows ContentView immediately
   - **Option B**: User needs to sign in again → Shows WelcomeView
4. If Option B, **tap** "Sign in with Apple"
5. **Apple Sheet**: Quick face ID / touch ID (Apple remembers you)
6. **Expect**: Sign in succeeds, shows ContentView

**What to Check**:
- ✅ Session persists between app launches (Option A is better UX)
- ✅ Sign in is fast (no email/name prompt, Apple remembers)
- ✅ Logs show: "UserAccount: Auth state changed: signedIn"

**Troubleshooting**:
- **Always asks for sign in** → Session not persisting, check Keychain access
- **Error after Face ID** → Check logs for Supabase auth error

---

### Test 3: Sign Out 🚪

**Goal**: Verify users can sign out cleanly

**Steps**:
1. **While signed in**, navigate to Profile/Settings view
2. **Find** "Sign Out" button (or in authentication challenge view)
3. **Tap** "Sign Out"
4. **Expect**:
   - Confirmation dialog appears
   - After confirming, returns to WelcomeView
   - All cached data cleared

**What to Check**:
- ✅ Logs show: "UserAccount: User signed out"
- ✅ Logs show: "Signed out from Supabase"
- ✅ Logs show: "Cleared [BankEntity|AccountEntity|TransactionEntity] cache"
- ✅ App shows WelcomeView (login screen)

**Troubleshooting**:
- **Still shows ContentView** → Check BabloApp.swift:24 logic
- **Data persists** → Check clearCoreDataCache() implementation

---

### Test 4: Biometric Authentication (App Lock) 🔐

**Goal**: Verify biometric auth works after app backgrounding

**Setup**:
1. Sign in successfully
2. If prompted, **enable biometric authentication**

**Steps**:
1. **Background app** (home button or swipe up)
2. **Wait 30 seconds** (timeout configured in AuthManager.swift:17)
3. **Return to app**
4. **Expect**:
   - ContentView is blurred
   - Biometric prompt appears automatically
5. **Authenticate** with Face ID / Touch ID
6. **Expect**:
   - Blur disappears
   - Full access to app

**What to Check**:
- ✅ Logs show: "BabloApp: Authentication overlay appeared - triggering biometrics"
- ✅ Logs show: "BabloApp: Authentication successful"
- ✅ Logs show: "AuthManager: Recorded successful authentication"

**Troubleshooting**:
- **No biometric prompt** → Check AuthManager timeout (may be < 30s)
- **Biometric fails** → Falls back to password view
- **Can't use password** → See Test 5

---

### Test 5: Password Fallback (Supabase Users) 🔄

**Goal**: Verify Supabase users see migration notice

**Steps**:
1. **Trigger biometric auth** (see Test 4)
2. **Cancel** Face ID / Touch ID
3. **Tap** "Use Password Instead"
4. **Expect**:
   - Sheet appears with message:
   - "Password Authentication Unavailable"
   - "Your account uses Sign in with Apple. Please sign out and sign back in with Apple to continue."
   - Shows "Sign Out" button (red)

**What to Check**:
- ✅ No password field shown (Supabase users don't have passwords)
- ✅ Clear messaging about using Sign in with Apple
- ✅ Only option is to sign out

**Troubleshooting**:
- **Shows password field** → User may be legacy user, check user ID format

---

### Test 6: Token Refresh 🔄

**Goal**: Verify Supabase automatically refreshes expired tokens

**Steps**:
1. **Sign in** and use app normally
2. **Leave app running** for 1+ hour
3. **Perform action** that requires authentication (e.g., refresh transactions)
4. **Expect**:
   - Action succeeds
   - No "session expired" error
   - Token refresh happens silently

**What to Check**:
- ✅ Logs show: "UserAccount: Auth state changed: tokenRefreshed"
- ✅ Logs show: "UserAccount: Token refreshed"
- ✅ User doesn't need to sign in again

**Troubleshooting**:
- **Session expired error** → Check Supabase refresh token settings
- **Frequent re-auth** → Token refresh not working, check logs

---

### Test 7: Multiple Devices 📱📱

**Goal**: Verify same Apple ID works across devices

**Steps**:
1. **Device 1**: Sign in with Apple (see Test 1)
2. **Device 2**: Sign in with SAME Apple ID
3. **Expect**:
   - Both devices signed in as same user
   - User ID is identical
   - Data syncs between devices (via Supabase)

**What to Check**:
- ✅ Same user ID on both devices
- ✅ Both can access same data
- ✅ Sign out on one doesn't affect the other

---

## Common Issues & Solutions

### Issue: "Invalid SUPABASE_URL format"
**Cause**: Missing or incorrect Supabase configuration
**Fix**:
1. Check `Config.swift` or build settings
2. Ensure URL starts with `https://`
3. Rebuild project

### Issue: "Authorization failed" (ASAuthorizationError)
**Cause**: Various Apple Sign In issues
**Fix**:
1. Check "Sign in with Apple" capability in Xcode
2. Verify bundle ID matches Apple Developer Portal
3. Check device has Apple ID signed in (Settings → Apple ID)
4. Try simulator vs real device

### Issue: User sees password authentication view
**Cause**: Legacy user (from pre-migration)
**Fix**: This is expected for legacy users. They should:
1. Use their old credentials once
2. Or sign out and use Sign in with Apple (recommended)

### Issue: "Session not found" after sign in
**Cause**: Supabase auth state not updating
**Fix**:
1. Check `UserAccount.swift:72` - observeAuthStateChanges()
2. Check Supabase logs in dashboard
3. Verify ANON_KEY is correct

---

## Verification Checklist

Before marking Phase 2 complete, verify:

### iOS Implementation
- [x] SupabaseManager properly initialized
- [x] SignInWithAppleCoordinator implemented
- [x] WelcomeView shows Sign in with Apple button
- [x] UserAccount observes Supabase auth state changes
- [x] Legacy fallback exists for old users
- [x] BabloApp properly wired with environment objects

### Functionality
- [ ] New user can sign in (Test 1)
- [ ] Returning user can sign in (Test 2)
- [ ] User can sign out (Test 3)
- [ ] Biometric auth works (Test 4)
- [ ] Password fallback shows migration notice (Test 5)
- [ ] Token refresh works silently (Test 6)
- [ ] Same user works across devices (Test 7)

### Code Quality
- [x] Legacy auth code archived
- [x] No broken imports in routes
- [x] Documentation updated (SUPABASE.md)
- [ ] No console errors during auth flow

---

## Testing Timeline

**Estimated Time**: 30-45 minutes

1. **Quick Pass** (15 min): Tests 1, 2, 3
2. **Full Pass** (30 min): All tests
3. **Soak Test** (1+ hour): Test 6 (token refresh)

---

## Debugging Tips

### Enable Verbose Logging
The app already has Logger statements. To see them:
1. Xcode → Product → Scheme → Edit Scheme
2. Arguments → Environment Variables
3. Add: `DEBUG=*` or specific modules

### Check Supabase Dashboard
1. Go to Authentication → Users
2. Verify user created after sign in
3. Check user metadata includes `full_name`

### Check iOS Console
Look for these key logs:
- ✅ "SupabaseManager: Initialized with URL: ..."
- ✅ "SignInWithAppleCoordinator: Starting Sign in with Apple flow"
- ✅ "SignInWithAppleCoordinator: Successfully signed in to Supabase"
- ✅ "UserAccount: Auth state changed: signedIn"
- ✅ "UserAccount: User signed out"

---

## Next Steps After Testing

Once all tests pass:

1. **Mark Phase 2 complete** in SUPABASE.md ✅
2. **Test Phase 3**: Webhook → sync flow
3. **Deploy Edge Functions** to production
4. **Monitor logs** for auth errors in production
5. **Consider removing legacy fallback** after all users migrated

---

## Questions?

- **Migration Plan**: See `/SUPABASE.md` Phase 2 section
- **Archived Code**: See `/server/archived/phase2-auth-migration/README.md`
- **iOS Implementation**: Check files with "Supabase Migration - Phase 2" comments

---

**Status**: ✅ Phase 2 implementation complete, ready for testing!
