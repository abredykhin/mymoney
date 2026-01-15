# MyMoney (Bablo)

**MyMoney** (internal codename: *Bablo*) is a modern, privacy-focused personal finance application designed for iOS. It helps users track finances, transactions, and budgets with a seamless, serverless architecture.

## 🚀 Overview

The project has recently migrated from a legacy Node.js/DigitalOcean infrastructure to a fully serverless stack using **Supabase** and **Native iOS**.

- **Mobile First**: Native iOS app built with SwiftUI and MVVM architecture.
- **Serverless Backend**: Powered by Supabase (Auth, PostgreSQL, Edge Functions).
- **Automated Sync**: Integrates with Plaid for seamless bank transaction updates.
- **Secure**: Row Level Security (RLS) ensures data isolation and privacy.

## 🛠 Tech Stack

- **iOS Client**: Swift, SwiftUI, Supabase Swift SDK.
- **Backend API**: Supabase Edge Functions (Deno/TypeScript).
- **Database**: PostgreSQL (Managed by Supabase).
- **Authentication**: Supabase Auth (Sign in with Apple).

## 📂 Project Structure

```bash
/Users/anton/ws/mymoney/
├── ios/                    # Native iOS Application
│   └── Bablo/              # Main App Source
├── supabase/               # Supabase Configuration
│   ├── functions/          # Deno Edge Functions (API)
│   ├── migrations/         # Database Schema & RLS
│   └── config.toml         # Project Config
└── server/                 # [Legacy] Reference only
```



## 🚦 Getting Started

### Prerequisites
- Xcode 15+
- [Supabase CLI](https://supabase.com/docs/guides/cli)

### Local Development

1.  **Start Supabase Locally**
    Run from the project root:
    ```bash
    supabase start
    ```

2.  **Open iOS Project**
    Open `ios/Bablo/Bablo.xcodeproj` in Xcode.

3.  **Run the App**
    Select a simulator or device and press Run (Cmd+R).

## ⚠️ Important Implementation Rules

- **Batch Inserts**: Transactions are synced using efficient batch inserts.
- **No Queues**: Background tasks use `ctx.waitUntil()` in Edge Functions instead of traditional queues.
- **Auth**: Uses Supabase Auth (JWT). No custom session tables.


