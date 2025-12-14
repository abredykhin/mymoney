# iOS Apple Sign In with Supabase - Setup Guide

**Phase 2 Migration: iOS Client Updates**
**Date**: December 11, 2025

This guide covers the manual steps you need to complete to enable Apple Sign In with Supabase in your iOS app.

---

## ✅ What's Already Done

The following code changes have been implemented:

1. ✅ **SupabaseManager.swift** - Manages Supabase client configuration
2. ✅ **SignInWithAppleCoordinator.swift** - Handles Apple Sign In flow
3. ✅ **UserAccount.swift** - Updated to work with Supabase Auth
4. ✅ **WelcomeView.swift** - New UI with Sign in with Apple button
5. ✅ **User model** - Extended to support Supabase sessions

---

## 🔧 Manual Steps Required

### Step 1: Add Supabase Swift SDK to Xcode Project

1. Open `Bablo.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies...**
3. Enter this URL: `https://github.com/supabase-community/supabase-swift.git`
4. Select **"Up to Next Major Version"** with version `2.0.0` or later
5. Click **"Add Package"**
6. Select both **"Supabase"** and **"Auth"** products
7. Click **"Add Package"**

**Verify**: You should see `supabase-swift` in the Package Dependencies section of your project navigator.

---

### Step 2: Add Required Files to Xcode Project

The following new files need to be added to your Xcode project:

1. In Xcode, right-click on the `Bablo` group in the Project Navigator
2. Select **"Add Files to 'Bablo'..."**
3. Navigate to and select these files:
   - `ios/Bablo/Bablo/Util/SupabaseManager.swift`
   - `ios/Bablo/Bablo/UI/Auth/SignInWithAppleCoordinator.swift`

4. Make sure **"Copy items if needed"** is UNCHECKED (files are already in the right location)
5. Make sure **"Bablo"** target is checked
6. Click **"Add"**

**Verify**: The files should appear in your Project Navigator and compile without errors.

---

### Step 3: Configure Supabase Credentials (Build Settings + Auto-Generated Config)

The iOS app uses a **build-time script** to generate `Config.swift` from Build Settings. This keeps credentials out of source control while making them easy to update.

#### How It Works:
1. Build Settings store `SUPABASE_URL` and `SUPABASE_ANON_KEY`
2. A Build Phase script generates `Util/Config.swift` automatically on each build
3. `SupabaseManager.swift` reads from the generated `Config.swift`

#### Setup Steps:

1. In Xcode, select your project in the Project Navigator
2. Select the **"Bablo"** target
3. Go to the **"Build Settings"** tab
4. Search for "SUPABASE" in the filter
5. You should see two custom build settings:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

6. Update their values:

   | Build Setting | Value |
   |--------------|-------|
   | `SUPABASE_URL` | Your Supabase project URL (e.g., `https://xyzproject.supabase.co`) or `http://localhost:54321` for local dev |
   | `SUPABASE_ANON_KEY` | Your Supabase anonymous key |

**Where to find these values:**
- Go to your Supabase Dashboard: https://supabase.com/dashboard
- Select your project
- Go to **Settings → API**
- Copy the **"Project URL"** → use for `SUPABASE_URL`
- Copy the **"anon public"** key → use for `SUPABASE_ANON_KEY`

**For local development:**
- Run `supabase start` in your `supabase/` directory
- Use `http://127.0.0.1:54321` or your local IP (e.g., `http://192.168.1.71:54321`) for `SUPABASE_URL`
- Get the anon key from the `supabase start` output

⚠️ **Important**:
- The anon key is safe to embed in your app - it's designed for client-side use
- Row Level Security (RLS) policies protect your data
- `Config.swift` is auto-generated and should NOT be edited manually
- `Config.swift` is in `.gitignore` to keep credentials out of source control

#### Verify Build Script:

The build phase script that generates Config.swift should already exist:

1. Select the **"Bablo"** target
2. Go to **"Build Phases"** tab
3. Look for a "Run Script" phase named something like "Generate Config"
4. It should contain:

```bash
# Generate Config.swift with build settings
CONFIG_FILE="${SRCROOT}/Bablo/Util/Config.swift"
cat > "$CONFIG_FILE" << EOF
  // Auto-generated file - DO NOT EDIT
  // Generated from Build Settings

  enum Config {
      static let supabaseURL = "${SUPABASE_URL}"
      static let supabaseAnonKey = "${SUPABASE_ANON_KEY}"
  }
EOF
```

**If the script doesn't exist**, add it:
1. Click **"+"** → **"New Run Script Phase"**
2. Drag it to run BEFORE "Compile Sources"
3. Paste the script above
4. Name it "Generate Config"

---

### Step 4: Enable Sign in with Apple Capability

1. In Xcode, select your project in the Project Navigator
2. Select the **"Bablo"** target
3. Go to the **"Signing & Capabilities"** tab
4. Click the **"+ Capability"** button
5. Search for and add **"Sign in with Apple"**

**Verify**: You should see "Sign in with Apple" listed in the capabilities.

---

### Step 5: Configure Apple Developer Console

⚠️ **Requires Apple Developer Account**

#### 5.1 Create/Update App ID

1. Go to https://developer.apple.com/account
2. Navigate to **Certificates, Identifiers & Profiles → Identifiers**
3. Find your app's **App ID** (e.g., `com.yourcompany.bablo`)
4. Click **"Edit"** or create a new one if needed
5. In the **Capabilities** list, check **"Sign In with Apple"**
6. Click **"Save"**

#### 5.2 Register Service ID (for Web/Future Use)

**Note**: This step is optional for native iOS apps but recommended for future web support.

1. In **Identifiers**, click the **"+"** button
2. Select **"Services IDs"**, click **"Continue"**
3. Enter:
   - **Description**: "Bablo Apple Sign In"
   - **Identifier**: `com.yourcompany.bablo.siwa` (must be unique)
4. Click **"Continue"**, then **"Register"**

---

### Step 6: Configure Supabase Dashboard for Apple Auth

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project
3. Go to **Authentication → Providers**
4. Find **"Apple"** in the list and enable it
5. You'll see two configuration options:

#### Option A: Native iOS Only (Simpler)

For native iOS apps, you can use Apple Sign In without additional configuration:
- **Enable Apple provider**: ✅
- Leave **Services ID** empty (not required for native apps)
- Leave **Secret Key** empty (not required for native apps)

#### Option B: Web + iOS (More Complex, for Future)

If you plan to support web later:
- **Services ID**: Enter the Service ID you created (e.g., `com.yourcompany.bablo.siwa`)
- **Secret Key (.p8)**: You'll need to generate this in Apple Developer Console
  - Go to **Keys** section in Apple Developer Console
  - Create a new key with "Sign in with Apple" enabled
  - Download the `.p8` file (keep it secure!)
  - Copy the key content to Supabase

6. Click **"Save"**

**For this migration, Option A (Native iOS Only) is sufficient.**

---

### Step 7: Update Info.plist for AuthenticationServices

This should already be configured, but verify:

1. Open `Info.plist` in Xcode
2. Ensure these privacy keys exist (they're required for AuthenticationServices framework):
   - `NSFaceIDUsageDescription` - "Used to authenticate you securely"
   - `NSAppleIDAuthorizationUsageDescription` - "Sign in with your Apple ID"

**Note**: If these are missing, add them as described in Step 3.

---

### Step 8: Build and Test

1. **Clean Build**: In Xcode, select **Product → Clean Build Folder** (Cmd + Shift + K)
2. **Build**: Select **Product → Build** (Cmd + B)
3. **Fix any compilation errors**:
   - Missing imports? Make sure Supabase package is added
   - File not found? Make sure files are added to target

4. **Run on Simulator or Device**:
   - Sign in with Apple works on **iOS Simulator** (iOS 14+) and **physical devices**
   - On simulator, it will use the Apple ID you're signed into on your Mac
   - On device, it will use the Apple ID signed into the device

5. **Test the flow**:
   - Launch the app
   - You should see the new Sign in with Apple button
   - Tap it and follow the Apple authentication flow
   - On first sign-in, Apple will ask for permissions (name, email)
   - After authentication, you should be signed in automatically

---

## 🔍 Troubleshooting

### "Missing Supabase configuration" Error

**Problem**: App crashes on launch with this message.

**Solution**: Make sure you've added `SUPABASE_URL` and `SUPABASE_ANON_KEY` to Info.plist (Step 3).

---

### "No code signature found" Error

**Problem**: Can't build or run the app.

**Solution**:
1. Go to **Signing & Capabilities** in Xcode
2. Make sure **"Automatically manage signing"** is checked
3. Select your development team
4. Clean build folder and rebuild

---

### Sign in with Apple Button Not Appearing

**Problem**: The button shows but doesn't work or doesn't appear.

**Solutions**:
1. Make sure **"Sign in with Apple"** capability is added (Step 4)
2. Make sure you're testing on iOS 14.0 or later
3. Check Console logs for errors related to `ASAuthorizationController`

---

### "Invalid Credentials" Error from Supabase

**Problem**: Apple authentication succeeds but Supabase sign-in fails.

**Solutions**:
1. Verify Apple provider is **enabled** in Supabase Dashboard (Step 6)
2. Check that your Bundle ID matches what's configured in Apple Developer Console
3. Look at Supabase logs: Dashboard → Logs → Auth logs
4. Verify the nonce implementation is working (check console logs)

---

### Token/Session Not Persisting

**Problem**: User is signed out every time they restart the app.

**Solution**:
- This should work automatically with Supabase SDK's `persistSession: true` option
- Check that UserAccount's `checkCurrentUser()` is being called on app launch
- Verify the Supabase session is being retrieved: `try await supabase.auth.session`
- Check Keychain access is working (Valet should have proper entitlements)

---

### "No window scene available" Error

**Problem**: Crash when presenting Sign in with Apple UI.

**Solution**:
- This usually means the app doesn't have an active window
- Make sure Sign in with Apple is triggered from an active view
- Check that `presentationAnchor` in SignInWithAppleCoordinator is working

---

## 🧪 Testing Checklist

Once everything is configured, test these scenarios:

- [ ] **First time sign in**: New user signs in with Apple
  - Full name and email should be captured
  - User should be signed in immediately
  - Session should persist after app restart

- [ ] **Subsequent sign ins**: Existing user signs in again
  - Should sign in without asking for name/email again
  - Session should be restored correctly

- [ ] **Sign out**: User signs out
  - Should return to WelcomeView
  - All data should be cleared
  - Keychain should be cleared

- [ ] **Biometric unlock still works**: After signing in with Apple
  - Face ID/Touch ID should still work for app unlock
  - Settings should persist

- [ ] **Token refresh**: Leave app open for a while
  - Access token should refresh automatically
  - No sign-out or errors should occur

---

## 📱 Migration Notes

### Backward Compatibility

The updated code maintains backward compatibility:
- **Legacy email/password methods** are deprecated but still functional
- **Old credentials in Keychain** will be migrated gradually
- **First run** will check for both Supabase and legacy sessions

### Migration Path for Existing Users

**Current behavior**:
1. User opens app
2. App checks for Supabase session first
3. If no Supabase session, falls back to legacy credentials
4. User can continue using legacy credentials temporarily

**Recommended approach**:
- Let users continue with legacy credentials
- Add a migration prompt: "Sign in with Apple is now available!"
- When user signs in with Apple, old credentials can be cleared

### Data Migration

**User profiles**:
- Supabase creates a new user in `auth.users`
- You may want to migrate data from old `users_table` to new `profiles` table
- Use the user's email as the matching key
- This can be done via a Supabase Edge Function (Phase 3)

---

## 🎯 Next Steps

After completing iOS migration:

1. **Test thoroughly** with both new and existing users
2. **Monitor Supabase logs** for any authentication errors
3. **Update API calls** to use Supabase Edge Functions (Phase 3)
4. **Remove legacy backend** once fully migrated

---

## 📚 References

- [Supabase Apple Sign In Docs](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Apple AuthenticationServices Framework](https://developer.apple.com/documentation/authenticationservices)
- [Supabase Swift SDK](https://github.com/supabase-community/supabase-swift)
- [Sign in with Apple - WWDC](https://developer.apple.com/sign-in-with-apple/)

---

## 💬 Questions or Issues?

If you encounter any issues during setup:

1. Check the console logs in Xcode for detailed error messages
2. Review the Supabase Dashboard logs (Authentication → Logs)
3. Verify all configuration steps were completed
4. Check that your Apple Developer account is active and in good standing

Common issues are usually related to:
- Missing or incorrect Supabase credentials
- Apple Developer Console configuration
- Xcode capabilities and entitlements
- Bundle ID mismatches
