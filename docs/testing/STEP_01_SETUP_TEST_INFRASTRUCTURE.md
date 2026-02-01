# Step 1: Setup Test Infrastructure

**Estimated Time:** 2-3 hours
**Prerequisites:** Deno installed, repository cloned
**Phase:** 1 - Infrastructure & Foundation

---

## Overview

This step sets up the foundational infrastructure for testing:
- Deno configuration for test commands
- Directory structure for test files
- Basic CI/CD workflow skeleton
- Test command validation

---

## Tasks

### Task 1.1: Create Deno Configuration

Create `supabase/functions/deno.jsonc`:

```jsonc
{
  "tasks": {
    "test": "deno test --allow-env --allow-net --allow-read --coverage=coverage",
    "test:watch": "deno test --allow-env --allow-net --allow-read --watch",
    "test:unit": "deno test --allow-env --allow-net --allow-read --ignore=**/*integration*.test.ts",
    "test:integration": "deno test --allow-env --allow-net --allow-read **/*integration*.test.ts",
    "test:coverage": "deno test --allow-env --allow-net --allow-read --coverage=coverage",
    "coverage": "deno coverage coverage --lcov --output=coverage.lcov",
    "test:check-coverage": "deno run --allow-read scripts/check-coverage.ts"
  },
  "exclude": [
    "coverage/"
  ],
  "compilerOptions": {
    "lib": ["deno.window", "dom"]
  }
}
```

**Why these permissions:**
- `--allow-env`: Tests need to read environment variables
- `--allow-net`: Tests may make network requests (mocked external APIs)
- `--allow-read`: Tests need to read fixture files
- `--coverage`: Generates coverage data for reporting

### Task 1.2: Create Coverage Check Script

Create `supabase/functions/scripts/check-coverage.ts`:

```typescript
/**
 * Parses LCOV coverage report and checks if coverage meets minimum threshold
 * Usage: deno run --allow-read scripts/check-coverage.ts
 */

const COVERAGE_THRESHOLD = 80; // Minimum 80% coverage required

async function main() {
  try {
    const lcovContent = await Deno.readTextFile('./coverage.lcov');

    // Parse LCOV format
    // LF = lines found, LH = lines hit
    const linesFound = lcovContent.match(/LF:(\d+)/g);
    const linesHit = lcovContent.match(/LH:(\d+)/g);

    if (!linesFound || !linesHit) {
      console.error('❌ Could not parse coverage data');
      Deno.exit(1);
    }

    const totalLines = linesFound
      .map(l => parseInt(l.split(':')[1]))
      .reduce((a, b) => a + b, 0);

    const totalHit = linesHit
      .map(l => parseInt(l.split(':')[1]))
      .reduce((a, b) => a + b, 0);

    const coveragePercent = (totalHit / totalLines) * 100;

    console.log(`\n📊 Coverage Report:`);
    console.log(`   Lines: ${totalHit}/${totalLines}`);
    console.log(`   Coverage: ${coveragePercent.toFixed(2)}%`);
    console.log(`   Threshold: ${COVERAGE_THRESHOLD}%\n`);

    if (coveragePercent < COVERAGE_THRESHOLD) {
      console.error(`❌ Coverage ${coveragePercent.toFixed(2)}% is below ${COVERAGE_THRESHOLD}% threshold`);
      Deno.exit(1);
    }

    console.log(`✅ Coverage meets ${COVERAGE_THRESHOLD}% threshold`);
    Deno.exit(0);

  } catch (error) {
    console.error('❌ Error reading coverage file:', error.message);
    console.error('   Make sure to run: deno task test:coverage && deno task coverage');
    Deno.exit(1);
  }
}

main();
```

### Task 1.3: Update .gitignore

Add to `.gitignore` (if not already present):

```gitignore
# Test coverage
supabase/functions/coverage/
supabase/functions/coverage.lcov

# Test environment
supabase/functions/.env.test
```

### Task 1.4: Create Initial GitHub Actions Workflow

Create `.github/workflows/test-edge-functions.yml`:

```yaml
name: Test Edge Functions

on:
  push:
    branches: [main]
    paths:
      - 'supabase/functions/**'
      - '.github/workflows/test-edge-functions.yml'
  pull_request:
    branches: [main]
    paths:
      - 'supabase/functions/**'
      - '.github/workflows/test-edge-functions.yml'

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Deno
        uses: denoland/setup-deno@v1
        with:
          deno-version: v1.x

      - name: Run tests
        working-directory: supabase/functions
        run: deno task test

      - name: Generate coverage report
        working-directory: supabase/functions
        run: deno task coverage

      - name: Check coverage threshold
        working-directory: supabase/functions
        run: deno task test:check-coverage

      - name: Upload coverage to Codecov (optional)
        if: false  # Enable this when ready to use Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./supabase/functions/coverage.lcov
          flags: edge-functions
          fail_ci_if_error: false
```

### Task 1.5: Create Test Utilities File Structure

Create placeholder for test utilities (will be filled in Step 2):

```bash
touch supabase/functions/_shared/test-utils.ts
touch supabase/functions/_shared/fixtures.ts
```

Add initial content to `supabase/functions/_shared/test-utils.ts`:

```typescript
/**
 * Shared test utilities for Edge Functions
 *
 * This file will contain:
 * - Mock Supabase client
 * - Mock Plaid client
 * - Mock request/response builders
 * - Fixture loaders
 * - Common test helpers
 */

// Re-export standard assertions for convenience
export {
  assertEquals,
  assertExists,
  assertRejects,
  assertStrictEquals,
  assertThrows,
  assertNotEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

// Placeholder - will be implemented in Step 2
export function createMockSupabaseClient(mockData: Record<string, any>): any {
  throw new Error('Not yet implemented - see Step 2');
}
```

---

## Validation

After completing all tasks, validate the setup:

### 1. Test Deno Configuration

```bash
cd supabase/functions

# Verify task configuration
deno task test
# Should output: "No tests found" (this is expected)

# Verify other tasks are recognized
deno task test:watch --help
deno task test:coverage --help
```

### 2. Verify Directory Structure

```bash
# Check all files exist
ls -la deno.jsonc
ls -la scripts/check-coverage.ts
ls -la _shared/test-utils.ts
ls -la ../.github/workflows/test-edge-functions.yml
```

### 3. Test Coverage Script

Create a dummy test to verify the coverage check works:

```typescript
// Create temporary test file: _test.ts
Deno.test("dummy test", () => {
  const x = 1 + 1;
  if (x !== 2) throw new Error("Math is broken");
});
```

Then run:

```bash
deno task test:coverage
deno task coverage
deno task test:check-coverage
```

Should output coverage report (may fail threshold check, which is fine).

Delete the dummy test file after validation:

```bash
rm _test.ts
rm -rf coverage/
rm coverage.lcov
```

### 4. Check GitHub Workflow Syntax

```bash
# If you have act installed (GitHub Actions local testing)
act -l

# Otherwise, just verify the YAML is valid
cat ../.github/workflows/test-edge-functions.yml
```

---

## Troubleshooting

### Issue: "deno: command not found"

**Solution:** Install Deno:
```bash
# macOS/Linux
curl -fsSL https://deno.land/install.sh | sh

# Then add to PATH (add to ~/.bashrc or ~/.zshrc):
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"
```

### Issue: "Permission denied" when creating files

**Solution:** Ensure you have write permissions to the repository:
```bash
# Check permissions
ls -la supabase/functions/

# If needed, fix permissions
chmod -R u+w supabase/functions/
```

### Issue: GitHub workflow not triggering

**Solution:**
- Ensure the workflow file is in `.github/workflows/` (not `supabase/.github/`)
- Check the file path in the `paths` filter matches your changes
- Verify YAML syntax is valid

---

## Commit

After validation, commit your changes:

```bash
git add supabase/functions/deno.jsonc
git add supabase/functions/scripts/check-coverage.ts
git add supabase/functions/_shared/test-utils.ts
git add supabase/functions/_shared/fixtures.ts
git add .github/workflows/test-edge-functions.yml
git add .gitignore

git commit -m "Setup test infrastructure for edge functions

- Add deno.jsonc with test tasks
- Create coverage check script with 80% threshold
- Add GitHub Actions workflow for CI/CD
- Create placeholder test utilities file
- Update .gitignore for test artifacts"
```

---

## Next Step

Proceed to [Step 2: Create Mock Utilities](./STEP_02_CREATE_MOCK_UTILITIES.md)
