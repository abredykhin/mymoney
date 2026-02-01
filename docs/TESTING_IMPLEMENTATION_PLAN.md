# Edge Functions Testing - Implementation Plan

**Status:** Ready for Implementation
**Created:** 2026-01-31
**Total Estimated Time:** 70-85 hours over 7-8 weeks

---

## Overview

This document provides the master implementation plan for adding comprehensive test coverage to the MyMoney Supabase Edge Functions. It addresses critical issues identified in the original testing plan review and breaks down the work into discrete, actionable steps that can be completed one at a time.

### Current State
- 7 edge functions with 3,284 lines of code
- 1 test file (15 tests in `sync-transactions/database.test.ts`)
- No standardized testing infrastructure

### Target State
- 80%+ code coverage across all functions
- Standardized testing patterns using Deno's built-in test framework
- CI/CD integration with coverage enforcement
- Fast, reliable test suite (<30 seconds runtime)

---

## Prerequisites

Before starting, ensure you have:

1. **Deno installed** (v1.x or later)
   ```bash
   deno --version
   ```

2. **Supabase CLI installed**
   ```bash
   supabase --version
   ```

3. **Local Supabase running**
   ```bash
   supabase start
   ```

4. **Access to repository**
   - Write access to create branches
   - Ability to create pull requests

5. **Understanding of the codebase**
   - Read `CLAUDE.md` for architecture overview
   - Familiarize yourself with the edge functions structure

---

## Implementation Steps

Each step below links to a detailed instruction file with complete implementation details. Steps are designed to be completed sequentially, with each building on the previous.

### Phase 1: Infrastructure & Foundation (Week 1)

**[Step 1: Setup Test Infrastructure](./testing/STEP_01_SETUP_TEST_INFRASTRUCTURE.md)**
- **Status:** ✅ Completed
- Create `deno.jsonc` configuration
- Set up directory structure
- Create GitHub workflow skeleton
- **Time estimate:** 2-3 hours
- **Validation:** Can run `deno task test` (even if no tests exist yet)

**[Step 2: Create Mock Utilities](./testing/STEP_02_CREATE_MOCK_UTILITIES.md)**
- **Status:** ✅ Completed
- Build working `MockQueryBuilder` with proper chaining
- Create realistic Supabase client mock
- Create Plaid client mock with correct signatures
- Create webhook signature generator
- **Time estimate:** 8-10 hours
- **Validation:** Mock utilities can be imported and used in test files
- **Critical:** This addresses the most important issue from the review

**[Step 3: Environment Setup](./testing/STEP_03_ENVIRONMENT_SETUP.md)**
- **Status:** ✅ Completed
- Create `.env.test` template
- Document all required environment variables
- Create environment loading utility
- Add to `.gitignore` if needed
- **Time estimate:** 2-3 hours
- **Validation:** Test files can load environment variables

### Phase 2: Shared Utilities Testing (Week 2)

**[Step 4: Test Shared Auth Module](./testing/STEP_04_TEST_SHARED_AUTH.md)**
- **Status:** ✅ Completed
- Create `_shared/auth.test.ts`
- Test all authentication functions
- Test CORS handling
- Test JWT validation
- **Time estimate:** 6-8 hours
- **Target coverage:** 90%+
- **Validation:** `deno test _shared/auth.test.ts` passes
- **Result:** 23 comprehensive tests, ~95% coverage achieved

**[Step 5: Test Shared Plaid Module](./testing/STEP_05_TEST_SHARED_PLAID.md)**
- **Status:** ✅ Completed
- Create `_shared/plaid.test.ts`
- Test Plaid client initialization
- Test error handling
- Test webhook signature validation
- **Time estimate:** 6-8 hours
- **Target coverage:** 85%+
- **Validation:** All Plaid utility functions tested
- **Result:** 28 comprehensive tests, ~90% coverage achieved

**[Step 6: Test Shared Recurring Module](./testing/STEP_06_TEST_SHARED_RECURRING.md)**
- **Status:** ✅ Completed
- Create `_shared/recurring.test.ts`
- Test transaction flag updates
- Test profile summary calculations
- **Time estimate:** 4-6 hours
- **Target coverage:** 90%+
- **Validation:** Recurring logic fully tested
- **Result:** 23 comprehensive tests, 100% coverage achieved

### Phase 3: Simple Functions (Week 3)

**[Step 7: Test Simple Functions](./testing/STEP_07_TEST_SIMPLE_FUNCTIONS.md)**
- Create `plaid-link-token/index.test.ts`
- Create `create-manual-stream/index.test.ts`
- Create `update-webhooks/index.test.ts`
- Test happy paths and error cases
- **Time estimate:** 10-12 hours
- **Target coverage:** 80%+ for each
- **Validation:** All three function test suites pass

### Phase 4: Complex Functions (Weeks 4-5)

**[Step 8: Test Complex Functions](./testing/STEP_08_TEST_COMPLEX_FUNCTIONS.md)**
- Create `save-item/index.test.ts`
- Create `sync-transactions/plaid.test.ts`
- Create `sync-transactions/index.test.ts`
- Create `sync-recurring-transactions/index.test.ts`
- Create `plaid-webhook/index.test.ts`
- **Time estimate:** 20-25 hours
- **Target coverage:** 75%+ for each
- **Validation:** All complex function tests pass

### Phase 5: CI/CD & Polish (Week 6)

**[Step 9: Setup CI/CD Pipeline](./testing/STEP_09_SETUP_CI_CD.md)**
- Complete GitHub Actions workflow
- Add coverage threshold enforcement
- Add coverage reporting to Codecov
- Test workflow with pull request
- **Time estimate:** 4-6 hours
- **Validation:** CI runs tests and enforces coverage

**[Step 10: Execute and Validate Tests](./testing/STEP_10_EXECUTE_AND_VALIDATE_TESTS.md)**
- Run complete test suite
- Generate coverage reports
- Identify and fix gaps
- Document any known issues
- Create testing guide for developers
- **Time estimate:** 6-10 hours
- **Validation:** 80%+ coverage achieved, all tests passing

---

## Testing Philosophy

### Test Layers

**Unit Tests** (90% of tests)
- Test individual functions in isolation
- Mock all external dependencies (Supabase, Plaid, Gemini)
- Fast (<1ms per test)
- Example: `_shared/auth.test.ts`

**Integration Tests** (10% of tests)
- Test multiple modules working together
- Mock only external APIs (Plaid, Gemini)
- May use real local Supabase instance
- Slower (~100ms per test)
- Example: Full sync flow tests

**E2E Tests** (not covered in this plan)
- Test entire flow from API request to database
- Use real local services
- Run separately from main test suite

### When to Mock vs Integrate

**Always Mock:**
- External API calls (Plaid, Gemini)
- Network requests
- Time-dependent operations (use fake timers)

**Consider Real Implementation:**
- Local Supabase database (for integration tests)
- Your own utility functions
- Pure data transformations

**Never Mock:**
- The function you're testing
- Simple data transformations
- Type definitions

---

## Success Criteria

### Quantitative
- ✅ All shared utilities have 85%+ coverage
- ✅ All simple functions have 80%+ coverage
- ✅ All complex functions have 75%+ coverage
- ✅ Overall codebase has 80%+ coverage
- ✅ Test suite runs in < 30 seconds locally
- ✅ Zero flaky tests (100% consistent pass/fail)
- ✅ CI/CD pipeline runs tests on every PR
- ✅ Coverage threshold enforced in CI

### Qualitative
- ✅ Tests catch regressions before production
- ✅ Developers feel confident making changes
- ✅ Test documentation exists
- ✅ New functions include tests from day 1
- ✅ Team understands testing patterns

---

## Running Tests

Once implementation is complete, use these commands:

```bash
# Navigate to functions directory
cd supabase/functions

# Run all tests
deno task test

# Run tests in watch mode (re-run on file changes)
deno task test:watch

# Run only unit tests (skip integration)
deno task test:unit

# Run with coverage
deno task test:coverage

# Generate coverage report
deno task coverage

# Run tests with coverage and check threshold
deno task test:coverage && deno task coverage && deno task test:check-coverage
```

---

## Timeline

| Week | Phase | Focus | Hours |
|------|-------|-------|-------|
| 1 | Phase 1 | Infrastructure & mocks | 12-16 |
| 2 | Phase 2 | Shared utilities | 16-22 |
| 3 | Phase 3 | Simple functions | 10-12 |
| 4-5 | Phase 4 | Complex functions | 20-25 |
| 6 | Phase 5 | CI/CD & polish | 10-16 |
| **Total** | | | **68-91 hours** |

---

## Key Improvements Over Original Plan

This implementation plan addresses critical issues identified in the review:

1. **Mock utilities are properly designed** - Step 2 includes working implementations with proper method chaining
2. **JWT handling is resolved** - Step 2 provides real JWT generation for tests
3. **Environment management is defined** - Step 3 creates complete env setup
4. **Database strategy is clear** - Mock-based approach for speed and reliability
5. **Integration vs unit boundary is defined** - Clear testing philosophy section
6. **CI/CD is complete** - Step 9 includes working coverage enforcement
7. **Test data strategy included** - Fixture patterns documented in Step 2
8. **Security testing included** - Step 4 covers RLS and authorization tests
9. **Error scenarios are detailed** - Each step includes comprehensive error cases
10. **Realistic examples provided** - All steps include working code samples

---

## Getting Started

1. **Review this document completely** to understand the full scope
2. **Read the detailed instructions** for Step 1
3. **Create a feature branch** for the testing work
4. **Begin with Step 1** and work through sequentially
5. **Validate each step** before moving to the next
6. **Commit after each major step** to track progress
7. **Create a PR** after Phase 1 is complete for early review
8. **Continue with remaining phases** after approval

---

## Support & Resources

### Documentation
- [Testing your Edge Functions | Supabase Docs](https://supabase.com/docs/guides/functions/unit-test)
- [Writing tests | Deno Docs](https://docs.deno.com/examples/testing_tutorial/)
- [Testing in isolation with mocks | Deno Docs](https://docs.deno.com/examples/mocking_tutorial/)

### Getting Help
- Check the troubleshooting section in each step document
- Review existing test file: `sync-transactions/database.test.ts`
- Consult Deno testing documentation
- Ask questions in team chat with context from specific step

---

## Next Steps

**Immediate Action:** Begin with [Step 1: Setup Test Infrastructure](./testing/STEP_01_SETUP_TEST_INFRASTRUCTURE.md)
