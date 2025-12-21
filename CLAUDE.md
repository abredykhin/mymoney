# MyMoney CLI Commands & Guidelines

## 🚀 Supabase Migration (IN PROGRESS)

**This project is migrating from Node.js/DigitalOcean to Supabase serverless architecture.**

### Documentation Structure
- **[SUPABASE.md](./SUPABASE.md)** - Complete migration plan, architecture, and implementation details
- **[MIGRATION_STATUS.md](./MIGRATION_STATUS.md)** - Current status, progress tracking, and next steps
- **This file** - Quick reference commands and guidelines

### Current Migration Status
- ✅ **Phase 1**: Database + RLS - **COMPLETE**
- ✅ **Phase 2**: Authentication (Sign in with Apple) - **COMPLETE**
- ✅ **Phase 3**: Edge Functions - **COMPLETE & DEPLOYED** 🚀
- ✅ **Phase 4**: iOS Services - **COMPLETE** 🎉
- 🔴 **Phase 5**: Scheduled Sync - **NOT STARTED** (Optional)

**🎊 CORE MIGRATION COMPLETE! All 4 main phases done. App is now fully on Supabase.**

**📊 See [MIGRATION_STATUS.md](./MIGRATION_STATUS.md) for detailed status**

### Quick Commands
**⚠️ IMPORTANT: Run all `supabase` commands from project root (`~/ws/mymoney`), NOT from `~/ws/mymoney/supabase`**

```bash
# Local Development
supabase start                         # Start local Supabase
supabase db reset                      # Apply migrations
supabase functions serve               # Serve all functions

# Deployment
supabase db push                       # Push migrations to production
supabase functions deploy <name>       # Deploy function
supabase secrets set KEY=value         # Set secrets

# Testing
supabase functions logs <name>         # View logs
supabase migration list                # Show migration status
```

### Key Architectural Decisions (READ THIS!)

**⚠️ CRITICAL - DO NOT IGNORE:**

1. **NO Bull/Redis Queues Needed**
   - Scale: ~300 transactions per sync = ~7 seconds
   - Use `ctx.waitUntil()` in Edge Functions for background tasks
   - Network I/O doesn't count toward CPU timeout

2. **MUST Use Batch Inserts**
   - ❌ NEVER: 300 individual INSERT statements
   - ✅ ALWAYS: Single batch INSERT for all transactions
   - See `SUPABASE.md` Section 3.0 for details

3. **No User Migration Needed**
   - Only test accounts exist in legacy DB
   - Using Supabase Auth (`auth.users`) for new accounts

4. **Authentication**
   - ❌ NO custom sessions table
   - ✅ Supabase Auth with JWT tokens
   - ✅ Sign in with Apple on iOS

**📖 Always consult [SUPABASE.md](./SUPABASE.md) before making architecture suggestions**

### Current Stack
- **Legacy** (being phased out): Node.js/Express on DigitalOcean
- **Target**: Supabase (PostgreSQL + Auth + Edge Functions)
- **iOS**: Native Swift/SwiftUI with Supabase SDK

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