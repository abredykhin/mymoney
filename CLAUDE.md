# Gemini Workspace Instructions

This document provides instructions for working with the MyMoney project, including the Supabase backend and the iOS application.

## Application Architecture

The application follows a client-server model.

-   **Client**: A native iOS application built with SwiftUI, following the Model-View-ViewModel (MVVM) pattern.
-   **Backend**: A serverless backend powered by Supabase, including a PostgreSQL database, authentication, and Deno-based Edge Functions.

### Key Components

#### iOS Client (`ios/Bablo`)

-   **`UI/`**: Contains all SwiftUI views, organized by feature (e.g., `Auth`, `Onboarding`, `Home`, `Transaction`).
-   **`Services/`**: Houses classes responsible for communicating with the backend (e.g., `PlaidService`, `EmailAuthService`, `AccountsService`). These services use the central `SupabaseManager` to make API calls.
-   **`Model/`**: Defines the core data structures and models used throughout the application (e.g., `UserAccount`).
-   **`Model/Cache/`**: Implements a local caching layer using Core Data (`CoreDataStack.swift`). This provides offline access and improves UI performance by reducing network requests. `AccountsManager` and `TransactionsManager` orchestrate the fetching from the network and saving to the local cache.
-   **`Util/`**: Contains helper classes and utilities, most importantly the `SupabaseManager.swift` singleton which manages the Supabase client and connection.

#### Supabase Backend (`supabase/`)

The `supabase/` directory contains all the backend infrastructure, managed by the Supabase CLI. It defines the database schema and holds the server-side business logic.

-   **`functions/`**: This directory contains all the server-side logic, written as Deno-based TypeScript Edge Functions. Each subdirectory is a distinct function.
    -   **`plaid-link-token`**: Generates a secure, short-lived `link_token` from Plaid, required to initialize the Plaid Link flow on the client.
    -   **`save-item`**: The core of the account linking process. It receives a `public_token` from the client, exchanges it for a permanent `access_token` with Plaid, and saves the new bank connection (`Item`) and its accounts to the database.
    -   **`sync-transactions`**: Fetches transactions for a given `Item` from Plaid using the stored `access_token` and updates the `transactions_table`.
    -   **`plaid-webhook`**: An endpoint that receives webhook events from Plaid (e.g., when new transactions are available) and triggers the appropriate action, such as running `sync-transactions`.
    -   **`gemini-budget-analysis`**: An AI-powered function that analyzes transaction history to identify recurring income and expenses, which are then used to build the user's budget profile.
    -   **`_shared/`**: A crucial directory for code reuse across all Edge Functions. It contains common logic for authentication, CORS handling (`auth.ts`), and initializing the Plaid client (`plaid.ts`).

-   **`migrations/`**: This directory holds the full history of database schema changes as incremental, timestamped SQL files. These migrations are generated and applied locally by the Supabase CLI (e.g., `supabase migration new`, `supabase db reset`), providing a version-controlled history of the database structure.

-   **`DEPLOY_TO_PRODUCTION.sql`**: This is a non-standard, manually-managed script that aggregates all the SQL from the `migrations/` directory. It serves as a master script to set up a new production database from scratch. It is executed directly in the Supabase Dashboard's SQL editor during initial setup or major deployments.

### Authentication Flow

Authentication is handled by Supabase Auth, providing a secure and streamlined experience.

1.  **Entry Point**: The user journey begins at `UI/Auth/WelcomeView.swift`, which offers "Sign in with Apple" and "Sign in with Email" options.
2.  **Email Authentication**: The app uses a passwordless, One-Time Password (OTP) flow.
    -   The user enters their email in `UI/Auth/EmailAuthView.swift`.
    -   `Services/EmailAuthService.swift` calls the `signInWithOTP` method from the Supabase client.
    -   Supabase sends a verification code to the user's email.
    -   The user enters the code in `UI/Auth/EmailOTPVerificationView.swift`.
    -   `EmailAuthService` verifies the token using the `verifyOTP` method.
3.  **Session Management**: Upon successful verification, Supabase returns a user session, and the user is considered logged in. The session is managed by the `SupabaseClient`.
4.  **New User Profile**: A PostgreSQL trigger (`handle_new_user`) on the `auth.users` table automatically creates a new record in the public `profiles_table` for first-time users.

### Data Flow

Financial data is sourced from Plaid, stored in Supabase, and cached on the device.

1.  **Data Source**: The primary source of truth for financial data is the Plaid API.
2.  **Fetching from Plaid**:
    -   The iOS app **never** communicates directly with Plaid.
    -   The `PlaidService` on the client calls Supabase Edge Functions (e.g., `sync-transactions`).
    -   These serverless functions securely execute requests to the Plaid API to fetch accounts, transactions, etc.
3.  **Storage in Supabase**: The data retrieved from Plaid is then inserted into the Supabase PostgreSQL database (e.g., `accounts_table`, `transactions_table`).
4.  **Syncing to iOS App**:
    -   `AccountsService` and `TransactionsService` query the Supabase backend to get the user's financial data.
    -   This data is then processed and stored locally in the on-device Core Data database via managers like `AccountsManager` and `TransactionsManager`.
    -   SwiftUI views (e.g., `HomeView`, `AllTransactionsView`) are powered by data from the local Core Data cache, ensuring a fast and responsive UI that can even function while offline.

## Budget Calculation

The application's budget calculation employs a hybrid approach, combining AI-powered backend analysis for identifying recurring financial patterns with client-side logic for real-time aggregation and display.

### Backend Analysis: `gemini-budget-analysis` Edge Function

This Supabase Edge Function (`supabase/functions/gemini-budget-analysis/index.ts`) is responsible for intelligently identifying recurring income and fixed expenses.

-   **Purpose**: Utilizes Gemini 2.0 Flash to analyze user transaction history and infer stable financial patterns.
-   **Trigger**: Invoked by the iOS app's `BudgetService` (`checkAndTriggerBudgetAnalysis` method) when the system detects linked accounts but no existing budget items.
-   **Process**:
    1.  Fetches a user's last 90 days of transactions from the Supabase `transactions` view.
    2.  Filters out transfers, very small amounts, and credit/loan account inflows to refine the dataset.
    3.  Formats the remaining transaction data into a detailed prompt for the Gemini 2.0 Flash model.
    4.  The Gemini model analyzes the data to identify recurring `income` and `fixed_expense` items, providing a `name`, `pattern`, `amount`, `frequency`, `monthly_amount`, `type`, `confidence` score (0.0-1.0), and `last_seen_date`.
    5.  Post-processing filters out potential false positives (e.g., "Payment" related items).
    6.  High-confidence items (>= 0.85) are `upserted` into the `budget_items_table`.
-   **Output**: Updates the user's `profiles_table` with calculated `monthly_income` and `monthly_mandatory_expenses` based on the identified high-confidence items.

### Client-Side Calculation: iOS `BudgetService`

The `ios/Bablo/Bablo/Services/BudgetService.swift` class drives the budget calculations within the iOS application, fetching data directly from Supabase tables and performing real-time aggregations. The `TotalBalanceView.swift` (`ios/Bablo/Bablo/UI/Budget/TotalBalanceView.swift`) is an example of a UI component that consumes this service.

-   **Key Calculations**:
    -   **Total Balance (Net Available Cash)**: Calculated by summing `current_balance` of "depository" accounts and subtracting `current_balance` of "credit" accounts (representing debt) from the `accounts` table.
    -   **Spending Breakdown**: Fetches `transactions` data for a specified period (week, month, year). Groups expenses by `personal_finance_category`, calculating `totalSpent`, `transactionCount`, and `percentOfTotal`. It intelligently filters out mandatory expenses if they have already occurred, providing a clearer view of variable spending.
    -   **Income Analysis**: Identifies actual income transactions for the current month, classifying them as `knownIncomeThisMonth` (matching patterns from `budget_items_table`) or `extraIncomeThisMonth` (one-off income).
    -   **Discretionary Budget**: The core budgeting metric, calculated as:
        `(max(expected_monthly_income_from_profile, known_income_this_month) + extra_income_this_month) - monthly_mandatory_expenses_from_profile - total_variable_spending_this_month`.
-   **Data Sources**: Directly queries Supabase tables and views: `accounts`, `transactions`, `profiles`, and `budget_items_table`.
-   **Data Models**: Utilizes Swift `struct`s like `TotalBalance`, `CategoryBreakdownItem`, and `BudgetItem` to represent and process financial data.

### Relevant Database Structures

-   **`profiles_table`**: Stores user-specific budget settings, including `monthly_income` and `monthly_mandatory_expenses` (updated by the `gemini-budget-analysis` function).
-   **`budget_items_table`**: Stores the recurring income and expense items identified by Gemini, including their patterns, amounts, frequencies, and confidence levels.
-   **`accounts` table/view**: Provides current balance information for all user accounts.
-   **`transactions` table/view**: Contains detailed transaction records, essential for spending breakdown and income analysis.

## Plaid Integration

Plaid is the core technology used to securely connect to a user's bank accounts and retrieve financial data. The integration is designed to be secure and robust, with all sensitive communication happening between the Supabase backend and Plaid's servers.

### The Account Linking Flow

The process of linking a new bank account involves a coordinated sequence between the iOS client and several Supabase Edge Functions.

1.  **User Initiation (iOS)**
    -   The user taps the "Link new account" button in `UI/Link/LinkButtonView.swift`.

2.  **`link_token` Generation (Client -> Backend -> Plaid)**
    -   The iOS `PlaidService` calls the `plaid-link-token` Supabase Edge Function.
    -   This function securely requests a short-lived `link_token` from the Plaid API, associating it with the Supabase `user.id`.

3.  **Plaid Link Presentation (iOS)**
    -   The `link_token` is returned to the iOS app.
    -   The app uses the token to configure and present the native Plaid Link modal. This is managed by the `LinkController` and the official Plaid `LinkKit` SDK. The user enters their banking credentials into this secure, sandboxed webview provided by Plaid.

4.  **Success Callback & `public_token` (Plaid -> Client)**
    -   Upon successful authentication, the Plaid SDK provides a `onSuccess` callback containing a temporary, one-time use `public_token`.

5.  **Token Exchange & Item Save (Client -> Backend -> Plaid -> Backend)**
    -   The iOS `PlaidService` sends the `public_token` to the `save-item` Supabase Edge Function.
    -   The `save-item` function is the core of the linking process:
        a.  It securely exchanges the `public_token` with the Plaid API for a permanent `access_token` and an `item_id`.
        b.  It stores the institution's details (name, logo) in the `institutions_table`.
        c.  It saves the new Plaid Item, including the encrypted `access_token` and `item_id`, to the `items_table`, linking it to the `user_id`.
        d.  It immediately fetches all accounts associated with the new Item and saves them to the `accounts_table`.

6.  **Initial Transaction Sync (Backend)**
    -   After successfully saving the Item and accounts, the `save-item` function triggers the `sync-transactions` Edge Function to download the initial batch of transactions for the newly linked account.

### Transaction Syncing

-   **Manual & Automated Syncs**: The `sync-transactions` function can be triggered manually or automatically. It uses the permanently stored `access_token` for a given Item to fetch the latest transactions from Plaid.
-   **Webhook Integration**: The backend is configured with a webhook URL (`plaid-webhook` function) that Plaid calls to notify the application of new transaction data. This allows for proactive, near real-time updates without requiring the user to manually refresh. The `plaid-webhook` function will then trigger the `sync-transactions` process for the relevant Item.

## Supabase Backend

All `supabase` commands should be executed from the root of the project repository.

### Local Development

1.  **Start the Supabase Stack:**
    To start the local Supabase services (PostgreSQL, Kong gateway, etc.), run:
    ```bash
    supabase start
    ```
    This command will also apply any new database migrations. Your local database connection details will be printed in the console.

2.  **Create New Migrations:**
    When you need to make a change to the database schema, create a new migration file:
    ```bash
    supabase migration new <migration_name>
    ```
    Replace `<migration_name>` with a descriptive name for your migration (e.g., `add_user_avatars`). Edit the generated SQL file in `supabase/migrations/` to define your schema changes.

3.  **Reset Local Database:**
    To wipe your local database and re-apply all migrations from the beginning, run:
    ```bash
    supabase db reset
    ```

### Production Deployment

To deploy database migrations to production, use the Supabase CLI:

```bash
supabase db push
```

This command will:
1. Compare your local migrations with the remote production database
2. Show you which migrations will be applied
3. Push any new migrations to the production database

**Important:** Review the migrations that will be applied before confirming the push.

## iOS Application

The native iOS application is built with SwiftUI.

### Building with Xcode

1.  **Open the Project:**
    Open the Xcode project file located at:
    `ios/Bablo/Bablo.xcodeproj`

2.  **Select Target and Device:**
    In the Xcode toolbar, select the `Bablo` scheme and choose an iOS Simulator (e.g., "iPhone 17 Pro") or a connected physical device.

3.  **Build and Run:**
    Click the **Run** button (or press `Cmd+R`) to build and launch the application.

### Building from the Command Line

You can also build the application using `xcodebuild` from the terminal. This is useful for scripting or CI/CD.

Navigate to the `ios/Bablo/` directory and run:

```bash
xcodebuild build -scheme Bablo -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

This command builds the `Bablo` scheme for the iPhone 17 Pro simulator. Adjust the `-destination` parameter as needed for other simulators or devices.
