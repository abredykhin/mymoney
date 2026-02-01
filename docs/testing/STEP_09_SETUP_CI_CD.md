# Step 9: Setup CI/CD Pipeline

**Estimated Time:** 4-6 hours
**Prerequisites:** Steps 1-8 completed (all tests written)
**Phase:** 5 - CI/CD & Polish

---

## Overview

Complete the GitHub Actions workflow to run tests automatically on every push and PR, with coverage enforcement.

---

## Implementation

### Task 9.1: Complete GitHub Actions Workflow

Update `.github/workflows/test-edge-functions.yml`:

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
    timeout-minutes: 10

    env:
      # Test environment variables
      SUPABASE_URL: http://localhost:54321
      SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY_TEST }}
      SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY_TEST }}
      SUPABASE_JWT_SECRET: ${{ secrets.SUPABASE_JWT_SECRET_TEST }}
      PLAID_CLIENT_ID: test
      PLAID_SECRET: test
      PLAID_ENV: sandbox
      PLAID_WEBHOOK_VERIFICATION_KEY: test
      TEST_MODE: true

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Deno
        uses: denoland/setup-deno@v1
        with:
          deno-version: v1.x

      - name: Cache Deno dependencies
        uses: actions/cache@v3
        with:
          path: |
            ~/.deno
            ~/.cache/deno
          key: ${{ runner.os }}-deno-${{ hashFiles('supabase/functions/**/*.ts') }}
          restore-keys: |
            ${{ runner.os }}-deno-

      - name: Run tests
        working-directory: supabase/functions
        run: deno task test

      - name: Generate coverage report
        working-directory: supabase/functions
        run: deno task coverage

      - name: Check coverage threshold
        working-directory: supabase/functions
        run: deno task test:check-coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./supabase/functions/coverage.lcov
          flags: edge-functions
          fail_ci_if_error: false
          token: ${{ secrets.CODECOV_TOKEN }}

      - name: Comment PR with coverage
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const lcov = fs.readFileSync('./supabase/functions/coverage.lcov', 'utf8');

            // Parse coverage
            const linesFound = lcov.match(/LF:(\d+)/g);
            const linesHit = lcov.match(/LH:(\d+)/g);

            if (!linesFound || !linesHit) return;

            const totalLines = linesFound.map(l => parseInt(l.split(':')[1])).reduce((a, b) => a + b, 0);
            const totalHit = linesHit.map(l => parseInt(l.split(':')[1])).reduce((a, b) => a + b, 0);
            const coverage = ((totalHit / totalLines) * 100).toFixed(2);

            const comment = `## 📊 Test Coverage Report

            - **Coverage:** ${coverage}%
            - **Lines:** ${totalHit}/${totalLines}
            - **Threshold:** 80%
            - **Status:** ${coverage >= 80 ? '✅ Passing' : '❌ Below threshold'}

            ${coverage < 80 ? '⚠️ Coverage is below the 80% threshold. Please add more tests.' : ''}
            `;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
```

### Task 9.2: Add GitHub Repository Secrets

In your GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add these secrets:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `SUPABASE_ANON_KEY_TEST` | Your local anon key | Run `supabase status` locally |
| `SUPABASE_SERVICE_ROLE_KEY_TEST` | Your local service role key | Run `supabase status` locally |
| `SUPABASE_JWT_SECRET_TEST` | Your local JWT secret | Check local Supabase config |
| `CODECOV_TOKEN` | Codecov upload token | Sign up at codecov.io (optional) |

**Note:** For CI, you can use the standard local Supabase keys since tests are mocked.

### Task 9.3: Add Status Badge to README

Add to the top of `supabase/functions/README_TESTING.md`:

```markdown
# Testing Edge Functions

[![Test Edge Functions](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/test-edge-functions.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/test-edge-functions.yml)
[![codecov](https://codecov.io/gh/YOUR_USERNAME/YOUR_REPO/branch/main/graph/badge.svg)](https://codecov.io/gh/YOUR_USERNAME/YOUR_REPO)

## Status
- ✅ All tests passing
- ✅ 80%+ code coverage
- ✅ CI/CD integrated
```

### Task 9.4: Create Pre-commit Hook (Optional)

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

echo "🧪 Running Edge Functions tests..."

cd supabase/functions

# Run tests
deno task test

if [ $? -ne 0 ]; then
  echo "❌ Tests failed. Commit aborted."
  echo "   Fix the failing tests or use 'git commit --no-verify' to skip."
  exit 1
fi

echo "✅ All tests passed!"
exit 0
```

Make it executable:

```bash
chmod +x .git/hooks/pre-commit
```

---

## Validation

### Test Locally

```bash
cd supabase/functions

# Run full test suite
deno task test

# Generate coverage
deno task test:coverage
deno task coverage

# Check threshold
deno task test:check-coverage
```

### Test CI Workflow

1. **Push to a feature branch:**
   ```bash
   git checkout -b test-ci-workflow
   git push origin test-ci-workflow
   ```

2. **Create a pull request** on GitHub

3. **Verify workflow runs:**
   - Check Actions tab in GitHub
   - Ensure all steps complete successfully
   - Verify coverage comment appears on PR
   - Check that badge shows "passing"

4. **Test failure scenario:**
   - Temporarily break a test
   - Push and verify CI fails
   - Fix and verify CI passes

---

## Troubleshooting

### Issue: "Secret not found"

**Solution:** Ensure all required secrets are added to GitHub:
- Settings → Secrets and variables → Actions
- Add each secret listed in Task 9.2

### Issue: Workflow doesn't trigger

**Solution:**
- Check the `paths` filter matches your changes
- Ensure workflow file is in `.github/workflows/` not `supabase/.github/`
- Verify YAML syntax is correct

### Issue: Tests pass locally but fail in CI

**Solution:**
- Check environment variables are set correctly in workflow
- Verify all dependencies are cached properly
- Check for file path issues (case sensitivity on Linux)
- Review CI logs for specific error messages

---

## Commit

```bash
git add .github/workflows/test-edge-functions.yml
git add supabase/functions/README_TESTING.md
git add .git/hooks/pre-commit  # If using pre-commit hook

git commit -m "Complete CI/CD pipeline for edge functions

- Add comprehensive GitHub Actions workflow
- Implement coverage threshold enforcement
- Add PR coverage comments
- Add status badges to README
- Add optional pre-commit hook
- Configure secrets for CI environment"
```

---

## Next Step

Proceed to [Step 10: Execute and Validate Tests](./STEP_10_EXECUTE_AND_VALIDATE_TESTS.md)
