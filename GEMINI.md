# MyMoney (Bablo) Project Analysis

## Project Overview
**MyMoney** (internally referred to as **Bablo**) is a personal finance application designed to help users track their finances, transactions, and budgets.

### High-Level Architecture
The system consists of three main components:
1.  **iOS Client:** A native Swift/SwiftUI application ("Bablo") that serves as the user interface.
2.  **Backend Server:** A Node.js/Express REST API that manages user data, authentication, and business logic.
3.  **Data Sources:**
    *   **PostgreSQL:** Primary relational database for storing user data, transactions, and configuration.
    *   **Plaid:** External financial API integrator used to securely connect to users' bank accounts and fetch transaction data.

### Infrastructure
The project uses **Docker** and **Docker Compose** for containerization of the server, database, and Nginx reverse proxy.
-   **Dev/Prod Parity:** Separate compose files for development (`docker-compose.dev.yml`) and production (`docker-compose.prod.yml`).
-   **Reverse Proxy:** Nginx is used to route traffic.

---

## Server Analysis
*Located in `/server`*

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
*Located in `/database`*

### Overview
The application uses **PostgreSQL** as its primary relational database. It stores user accounts, session tokens, and financial data synchronized from Plaid.

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

## Monitoring & Observability
*Production only (defined in `docker-compose.prod.yml`)*

### Overview
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

