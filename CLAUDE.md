# MyMoney CLI Commands & Guidelines

## Server Commands
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