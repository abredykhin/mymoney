# MyMoney (Bablo) Project Analysis

## Project Overview
**MyMoney** (internally referred to as **Bablo**) is a personal finance application designed to help users track their finances, transactions, and budgets.

### ⚠️ Architecture Migration in Progress
**The project is currently migrating from Node.js/DigitalOcean to Supabase.**

| Aspect | Legacy (Current) | Target (Supabase) | Status |
|--------|------------------|-------------------|--------|
| Backend Runtime | Node.js/Express | Deno Edge Functions | 🟡 In Progress |
| Database | PostgreSQL (DigitalOcean) | Supabase PostgreSQL | ✅ Migrated |
| Authentication | Custom (users/sessions tables) | Supabase Auth (JWT) | 🔴 Not Started |
| Queue/Jobs | Bull + Redis | Edge Functions only | 🟡 Planned |
| Deployment | Docker on Droplet | Serverless | 🔴 Not Started |

**📖 For detailed migration plan, architecture decisions, and implementation steps, see `SUPABASE.md`**

### High-Level Architecture (Legacy - Being Phased Out)
The current system consists of three main components:
1.  **iOS Client:** A native Swift/SwiftUI application ("Bablo") that serves as the user interface.
2.  **Backend Server:** A Node.js/Express REST API that manages user data, authentication, and business logic.
3.  **Data Sources:**
    *   **PostgreSQL:** Primary relational database for storing user data, transactions, and configuration.
    *   **Plaid:** External financial API integrator used to securely connect to users' bank accounts and fetch transaction data.

### Target Architecture (Supabase)
1.  **iOS Client:** Native Swift/SwiftUI app using Supabase SDK
2.  **Supabase Backend:**
    *   **Auth:** GoTrue (JWT-based authentication)
    *   **Database:** PostgreSQL with Row Level Security (RLS)
    *   **Edge Functions:** Deno-based serverless functions for:
        - Plaid webhook handling
        - Transaction syncing
        - Link token generation
3.  **Data Sources:**
    *   **Supabase PostgreSQL:** With RLS policies for multi-tenant security
    *   **Plaid:** Same external API integration

### Infrastructure (Legacy)
The current project uses **Docker** and **Docker Compose** for containerization of the server, database, and Nginx reverse proxy.
-   **Dev/Prod Parity:** Separate compose files for development (`docker-compose.dev.yml`) and production (`docker-compose.prod.yml`).
-   **Reverse Proxy:** Nginx is used to route traffic.

**Note:** Docker infrastructure will be eliminated in Supabase migration.

---

## Server Analysis (Legacy - Being Replaced by Supabase Edge Functions)
*Located in `/server`*

**⚠️ This Node.js/Express backend is being phased out in favor of Supabase Edge Functions. See `SUPABASE.md` for migration plan.**

### Overview
Backend service serving as a REST API connecting the mobile client (iOS) with the database and the Plaid financial data aggregator.

### Key Technologies
-   **Runtime:** Node.js
-   **Web Framework:** Express.js
-   **Database:** PostgreSQL
-   **ORM/Query Builder:** Knex.js (migrations), pg-promise/pg (queries)
-   **External Integrations:** Plaid API (banking data)
-   **Queue/Background Jobs:** Bull (Redis-based)
-   **Logging:** Winston, Morgan
-   **Testing:** Jest

### Architecture
The server follows a classic MVC-ish layered architecture:

1.  **Entry Point (`app.js`):** Configures Express, middleware (CORS, Body Parser, Logging), and mounts routes. Handles startup of HTTP server and background services (`refreshService`).
2.  **Routes (`routes/`):** Define API endpoints.
    -   `/users`: Authentication (Register/Login).
    -   `/link-token`: Plaid Link token generation.
    -   `/items`: Manage Plaid Items (bank connections).
    -   `/banks`: Retrieve bank/institution data.
    -   `/transactions`: Transaction history and management.
    -   `/budget`: Budgeting features.
    -   `/plaid`: Webhook handler for Plaid updates.
3.  **Controllers (`controllers/`):** Request handling logic.
    -   `dataRefresher.js`: Handles background data refresh jobs.
    -   `sessions.js`, `transactions.js`, `users.js`: Domain-specific logic.
4.  **Database Layer (`db/`):**
    -   `knexfile.js`: Configuration for database migrations.
    -   `migrations/`: Schema definitions and changes.
    -   `queries/`: Raw SQL or helper functions for database access (using `pg-promise` likely wrapped in `db/index.js`).
5.  **Middleware (`middleware/`):**
    -   Error handling.
    -   Authentication (likely JWT or session-based, used in protected routes).

### Configuration
-   **Environment Variables:** `.env` file (loaded via `dotenv`).
-   **Config Files:** `knexfile.js`, `jest.config.js`, `package.json`.

### Development
-   **Start Dev:** `npm start` (uses nodemon).
-   **Debug:** `npm run debug`.
-   **Test:** `npm test`.
-   **Lint:** `npm run lint` (ESLint).

### API Contract
See `openapi.yml` for the partial API specification.
-   **Base URL:** `http://localhost:3000` (Dev), `http://babloapp.com:5001` (Prod).

### Key Dependencies
-   `plaid`: For interacting with the Plaid API.
-   `bull`: For managing background data refresh tasks.
-   `winston`: For structured logging.

---

## iOS Client Analysis
*Located in `/ios`*

### Overview
The iOS client is a native **SwiftUI** application structured around the **MVVM** (Model-View-ViewModel) pattern. It serves as the primary user interface for the MyMoney/Bablo platform.

### Project Structure
The `ios` directory contains two main projects:
1.  **Bablo:** The main production application.
2.  **UxComponents:** A companion project likely used for isolated development and testing of reusable UI components (e.g., `TransactionView`, `AccountView`).

### Architecture (Bablo)
*   **Entry Point:** `BabloApp.swift` uses the SwiftUI `App` lifecycle. It orchestrates:
    *   **Dependency Injection:** Injects global state objects (`UserAccount`, `BankAccountsService`, `AuthManager`) into the environment.
    *   **Authentication Flow:** Handles biometric authentication (FaceID/TouchID) logic upon app launch or resume.
    *   **Core Data / SwiftData:** Initializes the local database stack.
*   **UI Layer (`UI/`):** Views are organized by feature domain:
    *   `Auth/`, `Onboarding/`: User registration and login flows.
    *   `Bank/`, `Transaction/`: Core financial data displays.
    *   `Budget/`, `Spend/`: Analytics and budgeting features.
    *   `HomeView.swift`: The central dashboard.
*   **Data Layer (`Model/`):**
    *   **Services:** `BankAccountsService`, `BudgetService`, `TransactionsService` encapsulate business logic and API interaction.
    *   **State Management:** `UserAccount` (Singleton/Shared Object) manages user session state.
    *   **Networking:** The app likely uses a generated API client (indicated by `openapi-generator-config.yaml`) based on the server's OpenAPI spec.
        *   `Util/Network/Client+Extensions.swift`: Configures the API client (switching between Dev/Prod environments).

### Key Features
*   **Biometric Security:** Strong integration with local authentication (FaceID/TouchID) via `BiometricsAuthService`.
*   **Data Persistence:** Uses Core Data (referenced as `CoreDataStack`) for local caching of data.
*   **Visual Design:** Includes a dedicated design system (`Design/`) with custom colors and components.

### Development Workflow
*   **API Generation:** The network layer is generated from `openapi.yml`, ensuring type safety and synchronization with the backend.
*   **Component Isolation:** The `UxComponents` project allows for rapid UI iteration without compiling the full app.


---

## Database Analysis
*Located in `/database` (legacy) and `/supabase/migrations` (new)*

**⚠️ Database schema has been migrated to Supabase with significant changes:**
- ✅ Migrated to Supabase PostgreSQL with Row Level Security (RLS)
- ⚠️ `users_table` → `profiles_table` (auth now handled by Supabase Auth)
- ⚠️ `sessions_table` → Removed (JWT tokens replace custom sessions)
- ✅ All tables have RLS policies enabled for multi-tenant security
- **See** `supabase/migrations/` for current schema and `SUPABASE.md` for details

### Overview (Legacy)
The application uses **PostgreSQL** as its primary relational database. It stores user accounts, session tokens, and financial data synchronized from Plaid.

**Current active schema:** See `supabase/migrations/20250101000000_initial_schema.sql`

### Schema Structure
The database schema uses a pattern of physical tables (suffixed with `_table`) and corresponding Views for data access. This abstraction allows for simplified querying and potential schema evolution without breaking application code.

#### Core Tables & Views
*   **Users & Auth:**
    *   `users_table`: Stores credentials and profile info.
    *   `sessions_table`: Manages authentication tokens (`session_token_status` enum).
*   **Financial Data (Plaid Integrated):**
    *   `items_table`: Represents a connection to a financial institution (Plaid Item).
    *   `accounts_table`: Individual bank accounts (checking, savings, etc.) linked to an Item.
    *   `transactions_table`: Transaction history. Note: `transaction_id` is the unique key from Plaid.
    *   `institutions_table`: Metadata about banks (names, logos, colors).
*   **Manual Data:**
    *   `assets_table`: User-entered asset values (e.g., property, cash).
*   **System & Logging:**
    *   `link_events_table` & `plaid_api_events_table`: Audit logs for Plaid interactions.
    *   `refresh_jobs`: Tracks background data refresh status (Bull/Redis job integration).

#### Key Patterns
*   **Views:** Almost every primary table has a corresponding View (e.g., `users`, `items`, `accounts`, `transactions`) which is the primary interface for the application.
*   **Timestamps:** Automatic `updated_at` maintenance via `trigger_set_timestamp()` trigger on all major tables.
*   **Data Types:** Currency values are stored as `numeric` but parsed as floats in the Node.js app.

### Schema Management
*   **Initialization:** `database/create.sql` contains the complete schema definition for setting up a new instance.
*   **Migrations:** Managed via **Knex.js** in `server/migrations/`.
    *   Recent migrations include adding `refresh_jobs` and `hidden` flags to accounts.

### Connection
*   **Library:** `node-postgres` (`pg`)
*   **Configuration:** `server/db/index.js` exports a connection Pool. It automatically parses PostgreSQL `numeric` types to JavaScript `float`.

---

## Monitoring & Observability (Legacy - Will Be Replaced)
*Production only (defined in `docker-compose.prod.yml`)*

**⚠️ This monitoring setup will be replaced by Supabase's built-in observability:**
- Supabase provides built-in logs for Edge Functions
- Database metrics available in Supabase Dashboard
- No need for self-hosted PLG stack in serverless architecture

### Overview (Legacy)
The application uses the **PLG Stack** (Promtail, Loki, Grafana) for centralized logging and monitoring in production.

### Components
1.  **Loki (Log Aggregation):**
    *   **Image:** `grafana/loki:2.9.2`
    *   **Role:** optimized datastore for logs (like Prometheus but for logs).
    *   **Storage:** Persists data to `loki-data` volume.
    *   **Port:** Internal `3100`.

2.  **Promtail (Log Shipper):**
    *   **Image:** `grafana/promtail:2.9.2`
    *   **Role:** Agent that ships local logs to a private Loki instance.
    *   **Scraping Targets** (defined in `promtail-config.yaml`):
        *   **App Logs:** `/var/log/app-logs/**/*` (Node.js application logs).
        *   **Nginx Logs:** `/var/log/nginx/ratelimit.log` (Rate limiting events).
        *   **Docker Containers:** Auto-discovers container logs via `/var/run/docker.sock`.

3.  **Grafana (Visualization):**
    *   **Image:** `grafana/grafana:11.6.0`
    *   **Role:** Dashboard UI for visualizing logs and metrics.
    *   **Access:** `https://babloapp.com/metrics` (served via Nginx subpath).
    *   **Provisioning:** Automatically configures Loki as a datasource via `grafana/provisioning/datasources/loki.yaml`.
    *   **Auth:** Basic Auth (admin/admin defined in docker-compose).

### Architecture
*   **Logs Flow:** Node.js App / Nginx -> Files -> Promtail -> Loki -> Grafana.
*   **Docker Logs Flow:** Docker Daemon -> Promtail -> Loki -> Grafana.

---

## Supabase Setup (New Architecture)
*Located in `/supabase`*

### Overview
The new architecture uses **Supabase** as a complete Backend-as-a-Service (BaaS) platform, eliminating the need for self-managed infrastructure.

### Project Structure
```
/supabase/
├── config.toml              # Supabase project configuration
├── migrations/              # Database migrations (PostgreSQL + RLS)
│   ├── 20250101000000_initial_schema.sql
│   └── 20250101000001_enable_rls.sql
└── functions/               # Edge Functions (Deno/TypeScript)
    ├── plaid-link-token/    # Generate Plaid Link tokens
    ├── plaid-webhook/       # Handle Plaid webhooks
    ├── sync-transactions/   # Sync transactions from Plaid
    └── [other functions]
```

### Components

#### 1. Database (Supabase PostgreSQL)
- **Managed PostgreSQL** with automatic backups and replication
- **Row Level Security (RLS)** enabled on all tables for multi-tenant data isolation
- **Schema Changes:**
  - `users_table` → `profiles_table` (linked to `auth.users` via UUID)
  - `sessions_table` → Removed (JWT tokens used instead)
  - All tables have `user_id` as UUID (not integer)
- **Migrations:** Applied via `supabase db reset` or `supabase db push`

#### 2. Authentication (Supabase Auth / GoTrue)
- **JWT-based authentication** (no custom session management)
- **Email/Password signup/login** built-in
- **Token refresh** handled automatically by SDK
- **Integration:** `profiles_table` auto-created via trigger on user signup

#### 3. Edge Functions (Deno Runtime)
- **Serverless functions** running on Deno Deploy
- **Key Functions:**
  - `plaid-link-token`: Generate Plaid Link tokens for iOS app
  - `plaid-webhook`: Receive webhooks from Plaid, trigger syncs
  - `sync-transactions`: Fetch and batch-insert transactions from Plaid
  - `total-balance`, `recent-transactions`: Read-only API endpoints
- **No Queue System:** Uses `ctx.waitUntil()` for background processing
- **Deployment:** `supabase functions deploy <name>`

#### Local Development

> [!CAUTION]
> **CRITICAL RULE**: All `supabase` CLI commands (start, functions deploy, db push, etc.) MUST be run from the **root project folder** (`/Users/anton/ws/mymoney`), NOT from the `/supabase` subdirectory.

```bash
# Start local Supabase (PostgreSQL + Auth + Edge Functions)
cd supabase && supabase start

# Apply migrations
supabase db reset

# Test Edge Function locally
supabase functions serve <name>

# View logs
supabase functions logs <name>
```

#### 5. Security (Row Level Security)
All tables have RLS policies that automatically filter data by `auth.uid()`:
- **profiles**: Users can only read/update their own profile
- **items**: Users can only access their own Plaid items
- **accounts**: Users can only access accounts linked to their items
- **transactions**: Users can only access their own transactions
- **institutions**: Public read-only (reference data)

### Key Differences from Legacy

| Aspect | Legacy | Supabase |
|--------|--------|----------|
| **Auth** | Custom users/sessions tables | Supabase Auth (JWT) |
| **User ID** | Integer `SERIAL` | UUID from `auth.users` |
| **Security** | Application-level filtering | Database-level RLS |
| **Background Jobs** | Bull + Redis | `ctx.waitUntil()` in Edge Functions |
| **Deployment** | Docker Compose on Droplet | `supabase functions deploy` |
| **Logs** | Self-hosted PLG stack | Supabase Dashboard |
| **Cost** | $12-20/month (Droplet + DB) | $0/month (Free tier) |

### Migration Status
- ✅ **Phase 1**: Database schema + RLS policies migrated
- 🟡 **Phase 2**: Authentication (in progress)
- 🟡 **Phase 3**: Edge Functions (in progress)
- 🔴 **Phase 4**: iOS client update (not started)
- 🔴 **Phase 5**: Scheduled sync with pg_cron (optional)

### Critical Implementation Notes
1. **Batch Inserts Required**: Legacy code uses individual INSERT statements (inefficient). Must use batch inserts in Edge Functions.
2. **Network I/O vs CPU**: Edge Function CPU limits only apply to compute, not network I/O (Plaid API calls, DB queries).
3. **No User Migration**: Only test accounts exist in legacy DB, so no actual user migration needed.
4. **Scale Expectations**: ~300 transactions per sync, <100 users, fits comfortably in free tier.

**📖 For complete migration plan, architecture decisions, gotchas, and implementation steps, see `SUPABASE.md`**


---

## Transaction Processing & Statistics
*Added Jan 2025*

### 1. Plaid Sign Logic (Source of Truth)
> [!IMPORTANT]
> **CRITICAL RULE**: The application follows the Plaid API standard for transaction amounts. This logic is used in the iOS Client, Edge Functions, and Database RPCs. **DO NOT CHANGE THIS LOGIC.**

- **Positive Amount (+100.00)**: Money moving **OUT** of the account.
  - Examples: Purchases, fixed expenses, lawyer payments, tax payments.
  - In code: `amount > 0`.
- **Negative Amount (-3500.00)**: Money moving **IN** to the account.
  - Examples: Direct deposits, salary, refunds, credit card payments (as seen from the credit account).
  - In code: `amount < 0`.

**Quote from Plaid API Documentation**:
> "Positive values when money moves out of the account; negative values when money moves in. For example, debit card purchases are positive; credit card payments, direct deposits, and refunds are negative."

### 2. In/Out Logic (Account Type Specifics)
While the sign logic above is absolute, the **interpretation** of inflows on specific account types is used for budget filtering:

| Account Type | Positive Amount ($100) | Negative Amount (-$100) |
|--------------|------------------------|-------------------------|
| **Standard** (Depository, Credit, Investment)| **Expense / Out** (Money leaving) <br> *e.g., Buying coffee* | **Income / In** (Money entering) <br> *e.g., Salary deposit* |
| **Loan** (Mortgage, Student Loan) | **Advance / In** (Principal increase) | **Payment / Out** (Principal decrease) |

### 3. Liability Account Inflow Rule (Ignore Rule)
> [!IMPORTANT]
> **CRITICAL RULE**: Any **Negative Amount (-)** (Money In) on a **Credit** or **Loan** account MUST be ignored for all primary budget and income calculations. 

- **Rationale**: Inflows on these accounts are almost exclusively **Credit Card Payments** (Transfers) or **Refunds**. They are not primary income.
- **Exceptions**: Inflows on **Depository** (Checking/Savings) accounts *are* considered potential income.
- **Application**: This rule is enforced in `gemini-budget-analysis` filtering and should be respected in any future budget aggregation logic.

**Note:** The application explicitly checks for `account.type ILIKE 'loan'` to apply this inversion.

### 2. Totals Calculation (Server-Side Stats)
To handle pagination correctly without downloading the entire transaction history, Monthly and Daily totals are calculated on the **Database (Server-Side)** via Supabase RPC functions.

*   **Migration:** `20251223000001_transaction_stats.sql`
*   **RPC Functions:**
    *   `get_monthly_transaction_stats(start_date, end_date)`: Grouped by Year/Month.
    *   `get_daily_transaction_stats(start_date, end_date)`: Grouped by Date.
*   **Logic:**
    *   Applies the In/Out logic described above.
    *   **Excludes Transfers:** Helper logic excludes transactions tagged with internal transfer categories or named "Payment/Transfer" to prevent double counting in spending reports.

### 3. iOS Implementation
*   `AllTransactionsView` fetches these stats (`fetchStats()`) in parallel with the transaction list.
*   It prefers the Server-Side stats for headers but falls back to Client-Side calculation if stats aren't loaded yet.

### 4. Database Performance
*   **Indexing:** Critical indexes were added to support high-performance aggregation and RLS:
    *   `transactions_table(user_id, date)`: For performant RPC aggregations.
    *   `transactions_table(user_id)`: For RLS filtering.
    *   Foreign Key indexes on `items_table`, `accounts_table`, `assets_table`, etc.
*   **Migration:** `20251223000002_add_transaction_indexes.sql` and `20251223000003_add_more_indexes.sql`.
### 4. Caching Strategy
*   **Caching Strategy:** Application-level caching was deemed unnecessary for current volumes (<300 txns/month) because Postgres aggregation with proper indexing takes <10ms.

### 5. Dynamic Budgeting Logic (The Effective Income Model)
The application uses a dynamic "Effective Income" model to calculate the Discretionary Budget. This model handles pay cycle variations (like the 3-paycheck month) and one-off windfalls without requiring manual user intervention.

#### Logic Overview:
- **Expected Baseline Income**: Stored in the user profile (calculated by Gemini analysis of last 90 days).
- **Known Income Patterns**: Actual transactions matching identified income patterns (e.g., "Salary", "Payroll").
- **Extra Income**: One-off inflows (e.g., "Venmo from Friend", "Tax Refund") that do not match identified patterns.

#### The Formula:
```
Effective Income = max(Expected Baseline, Known Income Received) + Extra Income Received
Discretionary Budget = Effective Income - Monthly Mandatory Expenses - Variable Spending
```

#### Why This Works:
1. **Bi-weekly Handling**: Early in the month, `max(Expected, Known)` defaults to the `Expected` baseline, ensuring the user sees their anticipated surplus. When a 3rd paycheck arrives, `Known Income` exceeds `Expected`, and the budget baseline automatically expands.
2. **One-off Windfalls**: Extra income is *always* added on top of the baseline, ensuring it increases the "Available to Spend" immediately rather than being swallowed by the monthly expectation.
3. **Liability Account Inflow Rule**: Inflows on Credit or Loan accounts are filtered out to prevent credit card payments or refunds from artificially inflating income.

---

## UI Component Rules (Bablo iOS)

### 1. Hero Carousel (`HeroCarouselView`)
- **Primary Purpose**: Displaying high-level financial health/balance summaries.
- **Content Restriction**: Should ONLY contain the **Net Available Cash** (Balance) card.
- **DO NOT** move secondary budget or spending cards into this carousel. 

### 2. Home Dashboard (`HomeView`)
- **Layout Order**:
    1. Navigation Header
    2. `HeroCarouselView` (Balance only)
    3. Vertical Stack of `HeroCardView` (Secondary Budget/Spending cards)
    4. Account List / Recent Transactions
- **Budget Logic**: Secondary cards (Discretionary Budget, Spending Breakdown) should be restored as standalone vertical cards below the carousel to maintain scanability and prominence.
- **Empty State**: Show `HeroBudgetEmptyStateView` ONLY when zero banks/accounts are linked. If accounts exist, show the calculated cards.



