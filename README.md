# MyMoney

**MyMoney** is a transparent, privacy-focused personal finance application built to help users take control of their financial life. It combines a seamless native iOS experience with a powerful serverless backend to track transactions, budgets, and net worth automatically.

## 🚀 Key Features

-   **Privacy First**: Your data is yours. Secured with Row Level Security (RLS) and stored safely in PostgreSQL.
-   **Automated Sync**: Seamlessly integrates with Plaid to fetch transactions from thousands of financial institutions.
-   **Smart Budgeting**: Proprietary "Effective Income" model adapts to variable pay cycles and one-off windfalls automatically.
-   **Native Experience**: Built entirely in SwiftUI for a fluid, responsive, and platform-native experience.

## 🛠 Tech Stack

-   **iOS Client**: Swift, SwiftUI, MVVM Architecture.
-   **Backend**: Supabase (PostgreSQL, Auth, Edge Functions).
-   **Language**: TypeScript (Deno) for backend logic.

## 📂 Project Structure

```bash
.
├── ios/                    # Native iOS Application
├── supabase/               # Backend Configuration & API
└── README.md
```

## 🚦 Getting Started

### Prerequisites
-   Xcode 15+
-   [Supabase CLI](https://supabase.com/docs/guides/cli)
-   Plaid Account (for transaction syncing)

### Local Development

1.  **Start the Backend**
    Run from the project root:
    ```bash
    supabase start
    ```

2.  **Open the App**
    Open `ios/Bablo/Bablo.xcodeproj` in Xcode.

3.  **Run**
    Select a simulator or device and press **Run** (Cmd+R).
