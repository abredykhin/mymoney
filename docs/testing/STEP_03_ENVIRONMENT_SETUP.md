# Step 3: Environment Setup

**Estimated Time:** 2-3 hours
**Prerequisites:** Steps 1-2 completed
**Phase:** 1 - Infrastructure & Foundation

---

## Overview

Set up environment variable management for tests, ensuring tests can run both locally and in CI without exposing secrets.

---

## Tasks

### Task 3.1: Create .env.test Template

Create `supabase/functions/.env.test.example`:

```bash
# Supabase Configuration
# For local testing, use your local Supabase instance values
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=test-anon-key-from-local-supabase
SUPABASE_SERVICE_ROLE_KEY=test-service-role-key-from-local-supabase
SUPABASE_JWT_SECRET=test-jwt-secret-from-local-supabase

# Plaid Configuration
# Use Plaid sandbox credentials for testing
PLAID_CLIENT_ID=test
PLAID_SECRET=test
PLAID_ENV=sandbox
PLAID_WEBHOOK_VERIFICATION_KEY=test-webhook-verification-key

# Gemini AI Configuration
# Not required for most tests (mocked)
GEMINI_API_KEY=test-gemini-key

# Test-specific settings
TEST_MODE=true
```

### Task 3.2: Create Actual .env.test File

Copy the example and fill in with real values from your local Supabase:

```bash
cd supabase/functions
cp .env.test.example .env.test

# Get your local Supabase credentials
cd ../..
supabase status

# Copy the values into .env.test:
# - API URL -> SUPABASE_URL
# - anon key -> SUPABASE_ANON_KEY
# - service_role key -> SUPABASE_SERVICE_ROLE_KEY
# - JWT secret (from local config) -> SUPABASE_JWT_SECRET
```

Example populated `.env.test`:

```bash
# Supabase Configuration (from supabase status)
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU
SUPABASE_JWT_SECRET=super-secret-jwt-token-with-at-least-32-characters-long

# Plaid - use sandbox for testing
PLAID_CLIENT_ID=your_sandbox_client_id
PLAID_SECRET=your_sandbox_secret
PLAID_ENV=sandbox
PLAID_WEBHOOK_VERIFICATION_KEY=your_webhook_verification_key

# Gemini (not required for most tests)
GEMINI_API_KEY=optional-for-mocked-tests

# Test mode
TEST_MODE=true
```

### Task 3.3: Add Environment Loading to Test Utilities

Add to the top of `supabase/functions/_shared/test-utils.ts`:

```typescript
import { load } from "https://deno.land/std@0.224.0/dotenv/mod.ts";

// Load test environment variables
let envLoaded = false;

/**
 * Loads test environment variables from .env.test file
 * Call this at the beginning of test files
 */
export async function setupTestEnvironment() {
  if (!envLoaded) {
    try {
      await load({
        envPath: new URL("../.env.test", import.meta.url).pathname,
        export: true,
      });
      envLoaded = true;
    } catch (error) {
      console.warn("Warning: Could not load .env.test file:", error.message);
      console.warn("Tests will use system environment variables");
    }
  }
}

// Rest of the file...
```

### Task 3.4: Update .gitignore

Ensure `.env.test` is ignored (but `.env.test.example` is committed):

```gitignore
# In root .gitignore
supabase/functions/.env.test
```

### Task 3.5: Document Environment Setup

Create `supabase/functions/README_TESTING.md`:

```markdown
# Testing Edge Functions

## Environment Setup

### Prerequisites

1. **Start local Supabase:**
   ```bash
   supabase start
   ```

2. **Create test environment file:**
   ```bash
   cd supabase/functions
   cp .env.test.example .env.test
   ```

3. **Populate with local values:**
   ```bash
   # Get your local credentials
   supabase status

   # Copy the values into .env.test
   # - API URL -> SUPABASE_URL
   # - anon key -> SUPABASE_ANON_KEY
   # - service_role key -> SUPABASE_SERVICE_ROLE_KEY
   ```

4. **Add Plaid sandbox credentials (optional):**
   - Sign up for Plaid sandbox account at https://dashboard.plaid.com/signup
   - Copy client_id and secret to .env.test
   - Most tests mock Plaid, so this is optional

### Running Tests

```bash
cd supabase/functions

# Run all tests
deno task test

# Run with watch mode
deno task test:watch

# Run with coverage
deno task test:coverage
deno task coverage
```

### Environment Variables

| Variable | Purpose | Where to Get |
|----------|---------|--------------|
| `SUPABASE_URL` | Local API URL | `supabase status` |
| `SUPABASE_ANON_KEY` | Anonymous key | `supabase status` |
| `SUPABASE_SERVICE_ROLE_KEY` | Admin key | `supabase status` |
| `SUPABASE_JWT_SECRET` | JWT signing secret | Local config file |
| `PLAID_CLIENT_ID` | Plaid sandbox ID | Plaid dashboard |
| `PLAID_SECRET` | Plaid sandbox secret | Plaid dashboard |
| `PLAID_ENV` | Plaid environment | Set to "sandbox" |
| `PLAID_WEBHOOK_VERIFICATION_KEY` | Webhook verification | Plaid dashboard |

### Troubleshooting

**Issue:** "Cannot load .env.test file"
- Ensure the file exists: `ls -la .env.test`
- Check file permissions: `chmod 644 .env.test`

**Issue:** "Invalid JWT secret"
- Get from Supabase local config: `cat ~/.supabase/config.toml | grep jwt_secret`
- Or use default local secret (from Supabase docs)

**Issue:** Tests fail with "Network error"
- Ensure local Supabase is running: `supabase status`
- Check URL matches local instance: `http://localhost:54321`
```

### Task 3.6: Update GitHub Actions for CI Environment

Update `.github/workflows/test-edge-functions.yml` to set environment variables:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest

    env:
      # Use test values for CI
      SUPABASE_URL: http://localhost:54321
      SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY_TEST }}
      SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY_TEST }}
      SUPABASE_JWT_SECRET: ${{ secrets.SUPABASE_JWT_SECRET_TEST }}
      PLAID_CLIENT_ID: test
      PLAID_SECRET: test
      PLAID_ENV: sandbox
      TEST_MODE: true

    steps:
      # ... existing steps
```

**Note:** You'll need to add these secrets to your GitHub repository:
- Settings → Secrets and variables → Actions → New repository secret
- Add: `SUPABASE_ANON_KEY_TEST`, `SUPABASE_SERVICE_ROLE_KEY_TEST`, `SUPABASE_JWT_SECRET_TEST`

---

## Validation

### Test Environment Loading

Create a temporary test file `supabase/functions/_test_env.ts`:

```typescript
import { setupTestEnvironment } from "./_shared/test-utils.ts";

Deno.test("Environment: should load test environment variables", async () => {
  await setupTestEnvironment();

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const plaidEnv = Deno.env.get('PLAID_ENV');

  console.log('SUPABASE_URL:', supabaseUrl);
  console.log('PLAID_ENV:', plaidEnv);

  if (!supabaseUrl) {
    throw new Error('SUPABASE_URL not loaded');
  }
});
```

Run:

```bash
cd supabase/functions
deno test _test_env.ts
```

Should output the environment variables. Delete after validation:

```bash
rm _test_env.ts
```

---

## Commit

```bash
git add supabase/functions/.env.test.example
git add supabase/functions/_shared/test-utils.ts
git add supabase/functions/README_TESTING.md
git add .github/workflows/test-edge-functions.yml
git add .gitignore

git commit -m "Setup test environment configuration

- Create .env.test template with all required variables
- Add environment loading to test utilities
- Document environment setup process
- Update CI workflow with test environment
- Add testing README with setup instructions"
```

---

## Next Step

Proceed to [Step 4: Test Shared Auth Module](./STEP_04_TEST_SHARED_AUTH.md)
