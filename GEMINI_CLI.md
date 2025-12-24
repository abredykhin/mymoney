# MyMoney (Bablo) Context for Gemini

**Last Updated Using**: `SUPABASE.md`, `MIGRATION_STATUS.md`, `CLAUDE.md` (Dec 2025)

## 🚀 Project Overview
**MyMoney** (Internal: **Bablo**) is a personal finance app tracking transactions and budgets.
**Architecture**: Serverless (Supabase) + Native iOS.
**Current State**: **Supabase Migration Phases 1-4 COMPLETE**. Legacy Node.js backend is deprecated.

## 🏗️ Architecture (Supabase-First)

### 1. Backend: Supabase
-   **Database**: PostgreSQL with **Row Level Security (RLS)**.
    -   **Auth**: Supabase Auth (GoTrue). No custom sessions table.
    -   **Logic**: Edge Functions (Deno). **NO** Node.js/Express servers.
    -   **Queues**: **NONE**. Use `ctx.waitUntil()` in Edge Functions.
-   **Security**:
    -   **RLS Policies**: Enforce data isolation. `user_id` matches `auth.uid()`.
    -   **Service Role**: Use only for webhooks/cron (bypasses RLS).

### 2. Frontend: iOS
-   **Tech**: Swift, SwiftUI, MVVM.
-   **SDK**: `supabase-swift` for Auth and Database.
-   **Auth**: Sign in with Apple (via Supabase). Legacy custom auth removed.

### 3. Integrations
-   **Plaid**: Financial data source.
    -   **Link Tokens**: Generated via Edge Function `plaid-link-token`.
    -   **Webhooks**: Handled by Edge Function `plaid-webhook`.
    -   **Sync**: Handled by Edge Function `sync-transactions` (direct sync, no queues).

## ⚠️ Critical Implementation Rules
1.  **Batch Inserts ONLY**:
    -   Top priority for performance.
    -   **Bad**: Loop with `insert()`.
    -   **Good**: `await supabase.from('table').insert([array_of_objects])`.
2.  **No Queues**:
    -   Legacy Bull/Redis system is DEAD.
    -   Use `ctx.waitUntil(promise)` in Edge Functions to handle async work without blocking response.
3.  **Network I/O**:
    -   Does NOT count towards Edge Function CPU limits.
    -   Large syncs (~300 items) are safe if logic is efficient.
4.  **Auth Context**:
    -   User-facing functions: `supabase.auth.getUser()`.
    -   Webhooks: `createClient(..., service_role_key)`.

## 📂 Project Structure
```
/Users/anton/ws/mymoney/
├── supabase/               # CORE BACKEND
│   ├── functions/          # Deno Edge Functions
│   │   ├── plaid-webhook/
│   │   ├── sync-transactions/
│   │   └── _shared/        # Shared code (DB, Auth utils)
│   ├── migrations/         # SQL Schema & RLS
│   └── config.toml
├── ios/
│   └── Bablo/              # Native iOS App
│       ├── Services/       # Supabase-based services
│       └── UI/             # SwiftUI Views
├── server/                 # LEGACY (Deprecated/Reference only)
└── database/               # LEGACY (Deprecated)
```

## 🛠️ Workflows & Commands

### Supabase (Run from Project Root)
-   **Start Local**: `supabase start`
-   **Reset DB**: `supabase db reset`
-   **Deploy Function**: `supabase functions deploy [function_name]`
-   **Set Secrets**: `supabase secrets set NAME=VALUE`
-   **Logs**: `supabase functions logs [function_name]`

### Development Cycle
1.  **Modify Schema**: Edit `supabase/migrations` -> `supabase db reset`.
2.  **Modify Edge Function**: Edit `supabase/functions/[name]/index.ts` -> `supabase functions serve`.
3.  **Deploy**: `supabase functions deploy [name]`.

## ✅ Current Status (Dec 2025)
-   **Database**: Migrated to Supabase + RLS.
-   **Auth**: Fully Supabase (Apple Sign In).
-   **Edge Functions**: Plaid Link, Webhooks, Sync (Optimized).
-   **iOS**: All services use Supabase SDK.
-   **Missing**: Optional Scheduled Sync (Phase 5).

## 📚 Reference Files
-   **`SUPABASE.md`**: The source of truth for architecture.
-   **`MIGRATION_STATUS.md`**: Detailed progress log.
-   **`supabase/migrations/`**: Current DB Schema.
