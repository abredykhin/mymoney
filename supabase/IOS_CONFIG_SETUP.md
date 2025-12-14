# iOS Configuration Setup - Build Script & Config Generation

**Quick Reference**: How Supabase credentials are managed in the iOS app

---

## Overview

The iOS app uses a **build-time script** to auto-generate configuration from Xcode Build Settings. This approach keeps credentials secure and makes environment switching easy.

## Architecture

```
┌─────────────────────────┐
│   Xcode Build Settings  │
│  - SUPABASE_URL         │
│  - SUPABASE_ANON_KEY    │
└───────────┬─────────────┘
            │
            │ (Build Phase Script)
            ▼
┌─────────────────────────┐
│ Util/Config.swift       │
│ (Auto-generated)        │
│                         │
│ enum Config {           │
│   static let            │
│     supabaseURL = "..." │
│   static let            │
│     supabaseAnonKey=".."│
│ }                       │
└───────────┬─────────────┘
            │
            │ (Import & Use)
            ▼
┌─────────────────────────┐
│  SupabaseManager.swift  │
│                         │
│  let client =           │
│    SupabaseClient(      │
│      supabaseURL:       │
│        Config.supabaseURL│
│      supabaseKey:       │
│        Config.supabase  │
│          AnonKey)       │
└─────────────────────────┘
```

## How It Works

### 1. Build Settings Store Credentials

In Xcode project settings:
- **Target**: Bablo
- **Tab**: Build Settings
- **Custom Settings**:
  - `SUPABASE_URL`: Project URL or local dev URL
  - `SUPABASE_ANON_KEY`: Anonymous/public API key

### 2. Build Phase Script Generates Config.swift

**Location**: Build Phases → "Generate Config" Run Script

**Script**:
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

**When it runs**: Before "Compile Sources" phase (on every build)

### 3. SupabaseManager Reads Config

**File**: `ios/Bablo/Bablo/Util/SupabaseManager.swift`

```swift
let supabaseURL = Config.supabaseURL
let supabaseAnonKey = Config.supabaseAnonKey

self.client = SupabaseClient(
    supabaseURL: URL(string: supabaseURL)!,
    supabaseKey: supabaseAnonKey
)
```

## Configuration Values

### Production
```
SUPABASE_URL = https://your-project-ref.supabase.co
SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

Get these from:
- Supabase Dashboard → Settings → API
- "Project URL" → `SUPABASE_URL`
- "anon public" key → `SUPABASE_ANON_KEY`

### Local Development
```
SUPABASE_URL = http://192.168.1.71:54321
SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

Get these from:
- Run `supabase start` in `supabase/` directory
- Copy the API URL (use your Mac's IP, not localhost, for iOS simulator)
- Copy the anon key from the output

**Why not localhost?**
- iOS Simulator: Use your Mac's local network IP (e.g., `192.168.1.71`)
- Physical device: Must use local network IP
- Backend on same machine: Use `127.0.0.1` only if backend is also on device

## Benefits

✅ **Security**: Credentials never committed to git
- `Config.swift` is in `.gitignore`
- Only Build Settings contain credentials (stored in Xcode project)

✅ **Flexibility**: Easy environment switching
- Different configs for Debug/Release builds
- Quick switch between local dev and production

✅ **Simplicity**: Zero manual file editing
- Auto-generates on every build
- No risk of stale config

✅ **Team-friendly**: Each developer sets their own values
- Build Settings are local to each machine
- No merge conflicts on config files

## Setup Checklist

- [ ] Build Settings contain `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- [ ] "Generate Config" Run Script exists in Build Phases
- [ ] Script runs BEFORE "Compile Sources"
- [ ] `Config.swift` is in `.gitignore` (already done)
- [ ] Build succeeds and generates `Util/Config.swift`
- [ ] SupabaseManager successfully initializes client

## Troubleshooting

### Error: "Cannot find 'Config' in scope"

**Cause**: Config.swift not generated or not in project

**Fix**:
1. Build the project (⌘B)
2. Check if `Bablo/Util/Config.swift` was created
3. If not, verify Build Phase script exists
4. Check script runs before "Compile Sources"

### Error: "Invalid SUPABASE_URL format"

**Cause**: Build Settings don't have values set

**Fix**:
1. Open project settings
2. Select "Bablo" target
3. Go to "Build Settings"
4. Search for "SUPABASE"
5. Add values if missing

### Config.swift shows wrong values

**Cause**: Stale generated file

**Fix**:
1. Clean build folder (⌘⇧K)
2. Rebuild (⌘B)
3. Config.swift will be regenerated

### iOS Simulator can't connect to local Supabase

**Cause**: Using `localhost` or `127.0.0.1`

**Fix**:
1. Find your Mac's local IP: System Settings → Network
2. Use IP address (e.g., `http://192.168.1.71:54321`)
3. Update `SUPABASE_URL` build setting
4. Rebuild

## File References

- **Generated Config**: `ios/Bablo/Bablo/Util/Config.swift` (gitignored)
- **Consumer**: `ios/Bablo/Bablo/Util/SupabaseManager.swift`
- **Build Script**: Xcode project → Bablo target → Build Phases → "Generate Config"
- **Gitignore Entry**: `.gitignore` line 86

## Additional Documentation

- **Setup Instructions**: See `IOS_APPLE_SIGNIN_SETUP.md` Step 3
- **Migration Overview**: See `PHASE2_MIGRATION_SUMMARY.md`
- **Supabase Plan**: See `SUPABASE.md` Phase 2

---

**Last Updated**: December 13, 2025
**Status**: ✅ Implemented and working
