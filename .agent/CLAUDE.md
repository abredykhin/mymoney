# MyMoney (Bablo) Context for Agent (Claude)

## �️ Component Map (Where Everything Is)

### 🔐 Authentication
- **Manager**: `ios/Bablo/Bablo/Util/SupabaseManager.swift`
- **Views**: `ios/Bablo/Bablo/UI/Auth/` (AuthenticationView, WelcomeView)

### � Budget & Analytics
- **Service**: `ios/Bablo/Bablo/Services/BudgetService.swift`
- **AI Analysis**: `supabase/functions/gemini-budget-analysis/`
- **Views**: `ios/Bablo/Bablo/UI/Home/` (HeroCarousel), `ios/Bablo/Bablo/UI/Spend/` (SpendView)

### 🏦 Transactions & Plaid
- **Service**: `ios/Bablo/Bablo/Services/TransactionsService.swift`
- **Sync Logic**: `supabase/functions/sync-transactions/`
- **Webhook**: `supabase/functions/plaid-webhook/`
- **Views**: `ios/Bablo/Bablo/UI/Transaction/AllTransactionsView.swift`

### 🏦 Accounts
- **Service**: `ios/Bablo/Bablo/Services/AccountsService.swift`
- **Views**: `ios/Bablo/Bablo/UI/Bank/BankListView.swift`

---

## 🚀 Project Overview
**Architecture**: Native iOS (SwiftUI) + Supabase (Serverless).

## ⚠️ Critical Rules

### 1. Database & Backend
- **Batch Inserts**: ALWAYS use batch inserts.
- **Edge Functions**: Use `ctx.waitUntil()` for background tasks. NO Queues.
- **Imports**: Use Deno-style URL imports (e.g., `npm:plaid`).

### 2. iOS Development
- **Dependency Injection**: Use `@EnvironmentObject` for global services.
- **Style**: MVVM. Keep Views small.

## 💡 Business Logic Recap
- **Transactions**: Negative = Income/Inflow. Positive = Spending/Outflow.
- **Budgeting**: "Effective Income" model.
- **Credit Cards**: Inflows on Credit/Loan accounts are IGNORED for income.

## ⚡ Quick Commands
Run from **root** (`~/ws/mymoney`):
```bash
supabase start                         # Start local dev
supabase functions deploy <name>       # Deploy function
supabase db reset                      # Reset DB
```