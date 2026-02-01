# Plaid Recurring Transactions Integration Plan

## Document Corrections Applied

**This document has been fully corrected and verified against actual sources:**

✅ **Database Schema Alignment**: All column references now match existing schema
- Changed: `personal_finance_category_primary` → `personal_finance_category`
- Changed: `personal_finance_category_detailed` → `personal_finance_subcategory`

✅ **Supabase SDK Error Handling**: Fixed `.single()` usage
- Removed hallucinated comment claiming `.single()` returns null
- Changed to proper error handling: check array length instead
- Pattern: `const existing = existingStreams?.[0];`

✅ **RECURRING_TRANSACTIONS_UPDATE Webhook**: Now using verified payload structure
- ✅ Confirmed fields: `webhook_type`, `webhook_code`, `item_id`, `account_ids`, `environment`
- Added `account_ids` logging for debugging

✅ **Partial Index Upsert Fix**: Replaced `.upsert()` with manual check-then-update
- Can't use `onConflict` with partial UNIQUE indexes in Supabase SDK
- Now uses explicit `if (existing) { update } else { insert }` pattern
- Safer and more explicit than relying on undocumented behavior

✅ **TOMBSTONED Status Handling**: Budget calculations now explicitly exclude ended subscriptions
- Added `status !== 'TOMBSTONED'` checks in all budget logic
- Prevents cancelled subscriptions from affecting budget forecasts

✅ **Error Handling & Rate Limits**: Comprehensive section added (Section 6)
- Plaid rate limits: 50 req/min for /transactions/sync, 30 req/min for /transactions/get
- Exponential backoff for HTTP 429 errors
- ITEM_LOGIN_REQUIRED error handling
- Network timeout retry logic

✅ **Code Organization**: Documented shared utilities pattern
- Extract duplicated functions to `/supabase/functions/_shared/recurring.ts`
- Reuse across `sync-recurring-transactions` and `create-manual-stream`

---

## Executive Summary

This plan outlines the complete replacement of the Gemini AI-based recurring transaction detection with Plaid's native `/transactions/recurring/get` endpoint. The integration will provide more accurate, real-time recurring transaction detection while allowing users to manually override classifications to ensure their discretionary budget calculations remain accurate.
