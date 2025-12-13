# Migration To-Do List (Supabase All-In)

**Phase 1: Supabase Project Setup & DB Migration**
- [ ] 1.1. Create a new Supabase project on their platform.
- [ ] 1.2. Execute your `database/create.sql` schema definitions within the Supabase SQL Editor to set up the database tables and views.
- [ ] 1.3. Migrate existing data from your DigitalOcean database to Supabase. (You can typically use `pg_dump` and `pg_restore` for this).
- [ ] 1.4. (Optional but recommended) Explore and enable Row Level Security (RLS) policies in Supabase for enhanced data protection.

**Phase 2: Authentication Migration (iOS & Backend)**
- [ ] 2.1. Update the iOS client application to use the Supabase Swift SDK for authentication (sign-up, log-in, session management). This will replace your custom auth logic.
- [ ] 2.2. Remove all custom authentication code from your Node.js backend (e.g., `server/controllers/users.js`, `server/controllers/sessions.js`, and related routes like `auth.js`). These will be fully managed by Supabase Auth.
- [ ] 2.3. Modify your `verifyToken` middleware (or replace it entirely) in the Edge Functions to validate Supabase JWTs.

**Phase 3: Porting Plaid Integration to Edge Functions**
- [ ] 3.1. Create a new Supabase Edge Function for Plaid Link Token creation. This will replace `server/routes/linkTokens.js`.
- [ ] 3.2. Create a new Supabase Edge Function to handle Plaid webhooks. This will replace `server/routes/webhook.js`. This function should trigger the background sync task.
- [ ] 3.3. Create a Supabase Edge Function with a Background Task to perform the full transaction sync. This will replace `server/controllers/transactions.js` and `server/controllers/dataRefresher.js`. Leverage `EdgeRuntime.waitUntil()` for the long-running parts.

**Phase 4: API Routes & Decommissioning**
- [ ] 4.1. Port remaining API routes (e.g., `/budget/totalBalance`, `/transactions/all`, `/transactions/recent`, `/transactions/breakdown/category`) to Supabase Edge Functions. These are generally simple data retrieval and perfect for standard Edge Functions.
- [ ] 4.2. Update the iOS client to call the new Supabase Edge Function endpoints.
- [ ] 4.3. Once all functionality is migrated and tested, decommission your DigitalOcean Node.js droplet.
