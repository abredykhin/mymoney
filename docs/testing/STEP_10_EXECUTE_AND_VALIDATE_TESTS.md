# Step 10: Execute and Validate Tests

**Estimated Time:** 6-10 hours
**Prerequisites:** Steps 1-9 completed
**Phase:** 5 - CI/CD & Polish

---

## Overview

Final step: Run the complete test suite, validate coverage, identify gaps, document known issues, and create testing guide for the team.

---

## Tasks

### Task 10.1: Run Complete Test Suite

```bash
cd supabase/functions

# Run all tests
deno task test

# Expected output:
# - All tests passing
# - No flaky tests
# - Runtime < 30 seconds
```

**If tests fail:**
1. Review error messages
2. Fix failing tests
3. Ensure mocks are working correctly
4. Check environment variables are loaded

### Task 10.2: Generate Coverage Report

```bash
# Generate coverage data
deno task test:coverage

# Generate LCOV report
deno task coverage

# Check threshold
deno task test:check-coverage
```

**Expected output:**
```
📊 Coverage Report:
   Lines: 2628/3284
   Coverage: 80.02%
   Threshold: 80%

✅ Coverage meets 80% threshold
```

### Task 10.3: Analyze Coverage Gaps

```bash
# Generate detailed HTML coverage report (optional)
deno coverage coverage --html

# Open in browser to see uncovered lines
open coverage/html/index.html
```

**Review uncovered code:**
- Identify which lines are not tested
- Determine if they're:
  - ✅ Error paths that are hard to trigger (acceptable)
  - ✅ Dead code that should be removed
  - ❌ Important logic that needs tests
  - ❌ Security-critical code (must be tested)

**Add tests for critical gaps** or document why they're untested.

### Task 10.4: Test Suite Health Check

Run tests multiple times to check for flakiness:

```bash
# Run 5 times in a row
for i in {1..5}; do
  echo "Run $i:"
  deno task test || echo "FAILED on run $i"
done
```

**All runs should pass.** If any fail:
- You have flaky tests (time-dependent, race conditions, etc.)
- Fix immediately - flaky tests are worse than no tests

### Task 10.5: Performance Check

```bash
# Time the test suite
time deno task test
```

**Target:** < 30 seconds total runtime

**If slower:**
- Identify slow tests
- Check for real network calls (should be mocked)
- Optimize slow test data setup
- Consider parallelization

### Task 10.6: Create Testing Documentation

Create `supabase/functions/TESTING.md`:

```markdown
# Edge Functions Testing Guide

## Quick Start

```bash
# Setup (first time only)
cd supabase/functions
cp .env.test.example .env.test
# Edit .env.test with your local Supabase credentials

# Run tests
deno task test

# Run with coverage
deno task test:coverage && deno task coverage
```

## Test Structure

```
supabase/functions/
├── _shared/
│   ├── auth.ts
│   ├── auth.test.ts           # Unit tests for auth
│   ├── plaid.ts
│   ├── plaid.test.ts          # Unit tests for Plaid
│   ├── recurring.ts
│   ├── recurring.test.ts      # Unit tests for recurring
│   └── test-utils.ts          # Shared test utilities
├── plaid-link-token/
│   ├── index.ts
│   └── index.test.ts          # Function tests
├── sync-transactions/
│   ├── index.ts
│   ├── index.test.ts          # Integration tests
│   ├── database.ts
│   ├── database.test.ts       # Unit tests for DB
│   ├── plaid.ts
│   └── plaid.test.ts          # Unit tests for Plaid
└── ... (other functions)
```

## Writing Tests

### 1. Import Test Utilities

```typescript
import {
  setupTestEnvironment,
  assertEquals,
  assertExists,
  createMockSupabaseClient,
  createMockPlaidClient,
  createTestJWT,
} from "../_shared/test-utils.ts";

// Load environment at top of file
await setupTestEnvironment();
```

### 2. Write Descriptive Test Names

```typescript
Deno.test("functionName: should do X when Y", async () => {
  // Arrange - Set up test data
  const mockClient = createMockSupabaseClient({
    mockData: { accounts: [...] }
  });

  // Act - Execute function
  const result = await functionName(mockClient, params);

  // Assert - Verify result
  assertEquals(result.success, true);
});
```

### 3. Test Happy Path and Error Cases

Always test:
- ✅ Happy path (normal successful execution)
- ✅ Error handling (API failures, invalid input)
- ✅ Edge cases (empty data, null values, extreme values)
- ✅ Security (auth failures, unauthorized access)

### 4. Use Mock Utilities

```typescript
// Mock Supabase
const mockSupabase = createMockSupabaseClient({
  mockData: {
    accounts: [{ id: 1, user_id: 'test-user' }]
  },
  mockErrors: {
    transactions: { code: '23505', message: 'duplicate key' }
  }
});

// Mock Plaid
const mockPlaid = createMockPlaidClient({
  transactionsSync: {
    added: [...],
    modified: [],
    removed: []
  }
});

// Mock authentication
const jwt = await createTestJWT({ userId: 'test-user' });
```

## Running Tests

```bash
# All tests
deno task test

# Watch mode (re-run on changes)
deno task test:watch

# Unit tests only
deno task test:unit

# Integration tests only
deno task test:integration

# Specific file
deno test path/to/file.test.ts -A

# With coverage
deno task test:coverage
deno task coverage
deno task test:check-coverage
```

## Coverage Goals

| Component | Target | Status |
|-----------|--------|--------|
| Shared utilities | 90%+ | ✅ Achieved |
| Simple functions | 80%+ | ✅ Achieved |
| Complex functions | 75%+ | ✅ Achieved |
| **Overall** | **80%+** | **✅ Achieved** |

## CI/CD

Tests run automatically on:
- Every push to `main`
- Every pull request
- Only when files in `supabase/functions/` change

**CI will fail if:**
- Any test fails
- Coverage drops below 80%
- Tests take longer than 10 minutes (timeout)

## Troubleshooting

### Tests fail locally but pass in CI (or vice versa)

**Cause:** Environment differences

**Solution:**
- Check environment variables in `.env.test`
- Ensure local Supabase is running: `supabase status`
- Verify Deno version matches CI: `deno --version`

### "Cannot load .env.test file"

**Cause:** Missing .env.test file

**Solution:**
```bash
cp .env.test.example .env.test
# Edit with your local values
```

### Flaky tests (sometimes pass, sometimes fail)

**Cause:** Time-dependent or async race conditions

**Solution:**
- Use `FakeTime` for time-dependent tests
- Ensure proper async/await usage
- Check for shared state between tests
- Fix immediately - flaky tests must not be committed

### Tests are slow (>30 seconds)

**Cause:** Real network calls or inefficient setup

**Solution:**
- Ensure all external APIs are mocked
- Reduce test data size
- Check for synchronous operations that could be parallel

## Best Practices

✅ **DO:**
- Test behavior, not implementation
- Use descriptive test names
- Follow AAA pattern (Arrange, Act, Assert)
- Test error paths
- Keep tests fast (<1ms per unit test)
- Make tests independent
- Use test utilities and fixtures

❌ **DON'T:**
- Test implementation details
- Over-mock (don't mock your own utilities)
- Skip edge cases
- Write brittle tests
- Commit failing or flaky tests
- Test third-party libraries
- Make tests dependent on execution order

## Resources

- [Deno Testing Docs](https://docs.deno.com/runtime/fundamentals/testing/)
- [Supabase Edge Functions Testing](https://supabase.com/docs/guides/functions/unit-test)
- [Original Testing Plan](../../docs/EDGE_FUNCTIONS_TESTING_PLAN.md)
```

### Task 10.7: Create Coverage Badge (Optional)

If using Codecov:

1. Sign up at https://codecov.io
2. Connect your GitHub repository
3. Get the badge markdown
4. Add to main README

### Task 10.8: Document Known Issues

Create `supabase/functions/TESTING_KNOWN_ISSUES.md`:

```markdown
# Known Testing Issues

## Current Limitations

### 1. Gemini AI Testing
**Issue:** AI responses are non-deterministic
**Workaround:** All Gemini tests use mocked responses
**Future:** Consider periodic manual validation against real API

### 2. Real Database Testing
**Issue:** Tests use mocked Supabase client, not real database
**Impact:** Database constraints and RLS policies not fully tested
**Workaround:** Manual testing with local Supabase
**Future:** Add integration tests with real local database

### 3. Webhook Timing
**Issue:** Background processing (ctx.waitUntil) is hard to test
**Workaround:** Test the logic separately from the background execution
**Future:** Investigate Deno's testing utilities for async background tasks

## Coverage Gaps

### Functions with <80% Coverage
- (List any functions that don't meet target, with explanation)

### Untested Code Paths
- Error handling for specific Plaid errors (too many variants)
- Rate limit exponential backoff edge cases
- Network timeout scenarios (hard to simulate)

## Flaky Tests
(None currently - update if any are discovered)

## Performance Issues
(None currently - update if test suite becomes slow)

## Last Updated
2026-01-31
```

---

## Validation Checklist

Before considering testing complete, verify:

- [ ] All test files created (Steps 4-8)
- [ ] All tests passing
- [ ] No flaky tests (5+ consecutive runs pass)
- [ ] Coverage ≥ 80% overall
- [ ] Test suite runs in < 30 seconds
- [ ] CI/CD workflow passing
- [ ] Coverage badge added (if using Codecov)
- [ ] Documentation complete
- [ ] Known issues documented
- [ ] Team trained on testing practices

---

## Final Commit

```bash
git add supabase/functions/TESTING.md
git add supabase/functions/TESTING_KNOWN_ISSUES.md
git add -A  # Add any remaining test fixes

git commit -m "Complete edge functions testing implementation

✅ All tests passing
✅ 80%+ coverage achieved
✅ CI/CD integrated and enforced
✅ Documentation complete
✅ Testing guide for team

Summary:
- 7 edge functions fully tested
- 3 shared utilities tested
- ~150+ test cases
- <30 second test runtime
- No flaky tests
- Coverage enforced in CI"
```

---

## Post-Implementation

### 1. Team Training

Schedule a session to:
- Walk through test structure
- Demonstrate writing a new test
- Show how to run tests locally
- Explain CI/CD integration
- Review best practices

### 2. Continuous Maintenance

**Weekly:**
- Review coverage reports
- Fix any flaky tests immediately

**Monthly:**
- Update dependencies (Deno std library)
- Review and update mock data if APIs change
- Check for new edge cases in production logs

**Per New Feature:**
- Tests required before merging
- Coverage must not decrease
- New functions must have 75%+ coverage

### 3. Celebrate! 🎉

You've built a comprehensive testing infrastructure that will:
- Catch bugs before production
- Enable confident refactoring
- Improve code quality
- Speed up development
- Reduce debugging time

---

## Next Steps Beyond Testing

Now that testing is solid, consider:

1. **Performance Testing:** Add benchmark tests for critical paths
2. **E2E Testing:** Test full flows with real services
3. **Load Testing:** Test under high transaction volumes
4. **Security Testing:** Penetration testing, SQL injection attempts
5. **Monitoring:** Add observability to catch issues in production

---

## Done!

Testing implementation is complete. Proceed to production deployment with confidence.
