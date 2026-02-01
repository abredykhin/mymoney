# Testing Edge Functions

## Environment Setup

### Prerequisites

1. **Start local Supabase:**
   ```bash
   supabase start
   ```

2. **Create test environment file:**
   ```bash
   cd supabase/functions
   cp .env.test.example .env.test
   ```

3. **Populate with local values:**
   ```bash
   # Get your local credentials
   supabase status

   # Copy the values into .env.test
   # - API URL -> SUPABASE_URL
   # - anon key -> SUPABASE_ANON_KEY
   # - service_role key -> SUPABASE_SERVICE_ROLE_KEY
   ```

4. **Add Plaid sandbox credentials (optional):**
   - Sign up for Plaid sandbox account at https://dashboard.plaid.com/signup
   - Copy client_id and secret to .env.test
   - Most tests mock Plaid, so this is optional

### Running Tests

```bash
cd supabase/functions

# Run all tests
deno task test

# Run with watch mode
deno task test:watch

# Run with coverage
deno task test:coverage
deno task coverage
```

### Environment Variables

| Variable | Purpose | Where to Get |
|----------|---------|--------------|
| `SUPABASE_URL` | Local API URL | `supabase status` |
| `SUPABASE_ANON_KEY` | Anonymous key | `supabase status` |
| `SUPABASE_SERVICE_ROLE_KEY` | Admin key | `supabase status` |
| `SUPABASE_JWT_SECRET` | JWT signing secret | Local config file |
| `PLAID_CLIENT_ID` | Plaid sandbox ID | Plaid dashboard |
| `PLAID_SECRET` | Plaid sandbox secret | Plaid dashboard |
| `PLAID_ENV` | Plaid environment | Set to "sandbox" |
| `PLAID_WEBHOOK_VERIFICATION_KEY` | Webhook verification | Plaid dashboard |

### Troubleshooting

**Issue:** "Cannot load .env.test file"
- Ensure the file exists: `ls -la .env.test`
- Check file permissions: `chmod 644 .env.test`

**Issue:** "Invalid JWT secret"
- Get from Supabase local config: `cat ~/.supabase/config.toml | grep jwt_secret`
- Or use default local secret (from Supabase docs)

**Issue:** Tests fail with "Network error"
- Ensure local Supabase is running: `supabase status`
- Check URL matches local instance: `http://localhost:54321`
