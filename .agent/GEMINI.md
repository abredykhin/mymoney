# MyMoney (Bablo) Context for Agent

## 🗺️ Component Map (Where Shit Is)

### 🔐 Authentication
**Logic**: `ios/Bablo/Bablo/Util/SupabaseManager.swift` (Singleton, Handles Session)
**UI**:
-   `ios/Bablo/Bablo/UI/Auth/AuthenticationView.swift` (Root Auth Switcher)
-   `ios/Bablo/Bablo/UI/Auth/SignInWithAppleCoordinator.swift` (Apple Sign In Logic)
-   `ios/Bablo/Bablo/UI/Auth/WelcomeView.swift` (Landing Page)

### 💰 Budget & Analytics
**Logic**:
-   `ios/Bablo/Bablo/Services/BudgetService.swift` (Calculates "Effective Income")
-   `supabase/functions/gemini-budget-analysis/index.ts` (AI Analysis of income patterns)
**UI**:
-   `ios/Bablo/Bablo/UI/Home/HeroCarouselView.swift` (Top Carousel - Balance Only)
-   `ios/Bablo/Bablo/UI/Home/HeroCardView.swift` (Budget Cards)
-   `ios/Bablo/Bablo/UI/Spend/SpendView.swift` (Spending Breakdown)

### 🏦 Transactions & Plaid
**Logic**:
-   `ios/Bablo/Bablo/Services/TransactionsService.swift` (Fetches & Caches Txns)
-   `ios/Bablo/Bablo/Services/PlaidService.swift` (Link Token Generation)
**Backend**:
-   `supabase/functions/sync-transactions/index.ts` (Batch Sync Logic)
-   `supabase/functions/plaid-webhook/index.ts` (Webhook Handler)
**UI**:
-   `ios/Bablo/Bablo/UI/Transaction/AllTransactionsView.swift` (Main List)
-   `ios/Bablo/Bablo/UI/Home/HomeView.swift` (Dashboard Layout)

### 🏦 Accounts
**Logic**: `ios/Bablo/Bablo/Services/AccountsService.swift`
**UI**: `ios/Bablo/Bablo/UI/Bank/BankListView.swift`

---

## 🚀 Architecture Overview
**Stack**: Supabase (Backend) + Native iOS (SwiftUI).
**State**: Pure Serverless. No Node.js. No Docker.

## ⚠️ Critical Implementation Rules
1.  **Batch Inserts ONLY**:
    -   Top priority. Never loop `insert()`.
    -   Use `supabase.from('table').insert([array])`.
2.  **No Queues**:
    -   Use `ctx.waitUntil(promise)` in Edge Functions.
3.  **Auth Context**:
    -   iOS: `SupabaseManager.shared`
    -   Edge Functions: `supabase.auth.getUser()`

## 💡 Core Business Logic

### 1. Transaction Signs (Plaid Standard)
> [!IMPORTANT]
> **DO NOT CHANGE THIS LOGIC.**

- **Positive (+)**: Money **OUT** (Purchases).
- **Negative (-)**: Money **IN** (Deposits).

### 2. Budget Filtering (The "Ignore Rule")
- **Negative Amount (-)** on **Credit** or **Loan** accounts MUST be ignored for income.
- **Why?**: These are payments/transfers, not income.

### 3. Effective Income Model
```
Effective Income = max(Expected Baseline, Known Income Received) + Extra Income Received
```

## 🛠️ Workflows
- **Deploy Function**: `supabase functions deploy <name>`
- **Reset DB**: `supabase db reset` (Run from root!)
