# MyMoney CLI Commands & Guidelines

## 🚀 Supabase Migration (IN PROGRESS)
**This project is migrating from Node.js/DigitalOcean to Supabase serverless architecture.**

### Quick Reference
- **Full Migration Plan**: See `SUPABASE.md` for comprehensive details
- **Status**: Phase 1 complete (database + RLS), Phase 2+ in progress
- **Local Supabase**: `cd supabase && supabase start`
- **Reset DB**: `supabase db reset` (applies migrations)
- **Deploy Function**: `supabase functions deploy <name>`

### Key Changes for LLMs
- ❌ **DO NOT** suggest Bull/Redis queues or Docker workers (not needed)
- ❌ **DO NOT** suggest migrating users/sessions (using Supabase Auth)
- ✅ **DO** use batch database inserts (not individual queries)
- ✅ **DO** use Edge Functions with `ctx.waitUntil()` for webhooks
- 📖 **READ** `SUPABASE.md` before making architecture suggestions

### Current Stack
- **Legacy**: Node.js/Express on DigitalOcean (being phased out)
- **Target**: Supabase (PostgreSQL + Auth + Edge Functions)
- **iOS**: Will update to use Supabase SDK

---

## Server Commands (Legacy - being deprecated)
- **Run Dev Server**: `npm start` or `./scripts/rebuild-dev.sh`
- **Run in Production**: `./scripts/rebuild-prod.sh`
- **Run Tests**: `npm test` or `docker-compose exec server npm test`
- **Run Single Test**: `docker-compose exec server npm test -- tests/unit/path/to/file.test.js`
- **DB Migrations**: `./scripts/run-db-migrations.sh`

## iOS
- Use Xcode to build, run and test the iOS app
- Unit Tests: Run tests via Xcode Test Navigator

## Code Style
### JavaScript
- Based on ESLint airbnb-base
- Import order: external libs → internal modules
- Consistent method JSDoc comments
- Error handling: Use Boom library (`@hapi/boom`)
- Logging: Use Winston logger with appropriate levels (`info`, `error`, etc.)

### Swift
- SwiftUI-based MVVM architecture
- Logger usage: `Logger.d/i/w/e()` for debug/info/warning/error
- Naming: camelCase for vars/methods, PascalCase for types
- Organize by feature (Bank, Transaction, etc.)
- Strong typing with proper error handling
- Use async/await for async operations