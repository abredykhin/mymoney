/**
 * Shared test utilities for Edge Functions
 */

import { load } from "https://deno.land/std@0.224.0/dotenv/mod.ts";

// Load test environment variables
let envLoaded = false;

/**
 * Loads test environment variables from .env.test file
 * Call this at the beginning of test files
 */
export async function setupTestEnvironment() {
  if (!envLoaded) {
    try {
      await load({
        envPath: new URL("../.env.test", import.meta.url).pathname,
        export: true,
      });
      envLoaded = true;
    } catch (error) {
      console.warn("Warning: Could not load .env.test file:", (error as Error).message);
      console.warn("Tests will use system environment variables");
    }
  }
}

// Re-export standard assertions
export {
  assertEquals,
  assertExists,
  assertRejects,
  assertStrictEquals,
  assertThrows,
  assertNotEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

// Re-export FakeTime for testing time-dependent code
export { FakeTime } from "https://deno.land/std@0.224.0/testing/time.ts";

/**
 * Mock Query Builder that supports method chaining
 * Simulates Supabase's query builder pattern
 */
class MockQueryBuilder {
  private mockData: any[];
  private filters: Array<{ column: string; value: any; operator: string }> = [];
  private selectColumns: string | undefined;
  private limitValue: number | undefined;
  private offsetValue: number | undefined;
  private orderByValue: { column: string; ascending: boolean } | undefined;
  private singleMode: boolean = false;
  private mockError: any = null;

  constructor(mockData: any[], mockError: any = null) {
    this.mockData = Array.isArray(mockData) ? mockData : [mockData];
    this.mockError = mockError;
  }

  select(columns: string = '*') {
    this.selectColumns = columns;
    return this;
  }

  insert(data: any) {
    if (this.mockError) {
      return { data: null, error: this.mockError };
    }
    const newData = Array.isArray(data) ? data : [data];
    return { data: newData, error: null };
  }

  upsert(data: any) {
    if (this.mockError) {
      return { data: null, error: this.mockError };
    }
    const newData = Array.isArray(data) ? data : [data];
    return { data: newData, error: null };
  }

  update(data: any) {
    // Return a chainable object for .eq() etc
    return {
      eq: (column: string, value: any) => {
        if (this.mockError) {
          return { data: null, error: this.mockError };
        }
        return { data: [data], error: null };
      },
      match: (filters: Record<string, any>) => {
        if (this.mockError) {
          return { data: null, error: this.mockError };
        }
        return { data: [data], error: null };
      },
    };
  }

  delete() {
    return {
      eq: (column: string, value: any) => {
        if (this.mockError) {
          return { data: null, error: this.mockError };
        }
        return { data: null, error: null };
      },
      match: (filters: Record<string, any>) => {
        if (this.mockError) {
          return { data: null, error: this.mockError };
        }
        return { data: null, error: null };
      },
    };
  }

  eq(column: string, value: any) {
    this.filters.push({ column, value, operator: 'eq' });
    return this;
  }

  neq(column: string, value: any) {
    this.filters.push({ column, value, operator: 'neq' });
    return this;
  }

  gt(column: string, value: any) {
    this.filters.push({ column, value, operator: 'gt' });
    return this;
  }

  gte(column: string, value: any) {
    this.filters.push({ column, value, operator: 'gte' });
    return this;
  }

  lt(column: string, value: any) {
    this.filters.push({ column, value, operator: 'lt' });
    return this;
  }

  lte(column: string, value: any) {
    this.filters.push({ column, value, operator: 'lte' });
    return this;
  }

  is(column: string, value: any) {
    this.filters.push({ column, value, operator: 'is' });
    return this;
  }

  in(column: string, values: any[]) {
    this.filters.push({ column, value: values, operator: 'in' });
    return this;
  }

  order(column: string, options: { ascending?: boolean } = {}) {
    this.orderByValue = {
      column,
      ascending: options.ascending !== false,
    };
    return this;
  }

  limit(count: number) {
    this.limitValue = count;
    return this;
  }

  range(from: number, to: number) {
    this.offsetValue = from;
    this.limitValue = to - from + 1;
    return this;
  }

  single() {
    this.singleMode = true;
    if (this.mockError) {
      return { data: null, error: this.mockError };
    }

    const filtered = this.applyFilters();
    const data = filtered.length > 0 ? filtered[0] : null;
    return { data, error: null };
  }

  maybeSingle() {
    return this.single();
  }

  private applyFilters(): any[] {
    let result = [...this.mockData];

    for (const filter of this.filters) {
      result = result.filter(row => {
        if (!row) return false;

        const rowValue = row[filter.column];

        switch (filter.operator) {
          case 'eq':
            return rowValue === filter.value;
          case 'neq':
            return rowValue !== filter.value;
          case 'gt':
            return rowValue > filter.value;
          case 'gte':
            return rowValue >= filter.value;
          case 'lt':
            return rowValue < filter.value;
          case 'lte':
            return rowValue <= filter.value;
          case 'is':
            return rowValue === filter.value;
          case 'in':
            return filter.value.includes(rowValue);
          default:
            return true;
        }
      });
    }

    // Apply ordering
    if (this.orderByValue) {
      const { column, ascending } = this.orderByValue;
      result.sort((a, b) => {
        const aVal = a[column];
        const bVal = b[column];
        if (aVal < bVal) return ascending ? -1 : 1;
        if (aVal > bVal) return ascending ? 1 : -1;
        return 0;
      });
    }

    // Apply limit and offset
    if (this.offsetValue !== undefined) {
      result = result.slice(this.offsetValue);
    }
    if (this.limitValue !== undefined) {
      result = result.slice(0, this.limitValue);
    }

    return result;
  }

  // Terminal operation - returns promise-like object
  then(resolve: (value: any) => void, reject?: (error: any) => void) {
    if (this.mockError) {
      const error = { data: null, error: this.mockError };
      if (reject) reject(error);
      return Promise.resolve(error);
    }

    const filtered = this.applyFilters();
    const data = this.singleMode
      ? (filtered.length > 0 ? filtered[0] : null)
      : filtered;

    const result = { data, error: null };
    resolve(result);
    return Promise.resolve(result);
  }
}

/**
 * Creates a mock Supabase client for testing
 */
export function createMockSupabaseClient(options: {
  mockData?: Record<string, any[]>;
  mockErrors?: Record<string, any>;
  userId?: string;
} = {}) {
  const { mockData = {}, mockErrors = {}, userId = 'test-user-id' } = options;

  return {
    from: (table: string) => {
      const tableData = mockData[table] || [];
      const tableError = mockErrors[table] || null;
      return new MockQueryBuilder(tableData, tableError);
    },

    auth: {
      getUser: (jwt?: string) => {
        if (mockErrors.auth) {
          return Promise.resolve({ data: { user: null }, error: mockErrors.auth });
        }
        return Promise.resolve({
          data: { user: { id: userId, email: `${userId}@test.com` } },
          error: null,
        });
      },
    },

    rpc: (functionName: string, params?: any) => {
      const rpcData = mockData[functionName] || null;
      const rpcError = mockErrors[functionName] || null;
      return Promise.resolve({ data: rpcData, error: rpcError });
    },

    functions: {
      invoke: (functionName: string, options?: any) => {
        const fnData = mockData[functionName] || {};
        const fnError = mockErrors[functionName] || null;
        return Promise.resolve({ data: fnData, error: fnError });
      },
    },
  };
}

/**
 * Creates a mock Request object for testing
 */
export function createMockRequest(options: {
  method?: string;
  url?: string;
  headers?: Record<string, string>;
  body?: any;
} = {}): Request {
  const {
    method = 'GET',
    url = 'http://localhost',
    headers = {},
    body,
  } = options;

  const requestInit: RequestInit = {
    method,
    headers: new Headers(headers),
  };

  if (body !== undefined) {
    requestInit.body = typeof body === 'string' ? body : JSON.stringify(body);
  }

  return new Request(url, requestInit);
}

/**
 * Creates a mock Response for testing
 */
export function createMockResponse(
  body: any,
  options: { status?: number; headers?: Record<string, string> } = {}
): Response {
  const { status = 200, headers = {} } = options;

  return new Response(JSON.stringify(body), {
    status,
    headers: new Headers(headers),
  });
}

/**
 * Creates a mock Plaid client for testing
 * Methods match the real Plaid Node SDK signatures
 */
export function createMockPlaidClient(mockResponses: {
  linkTokenCreate?: any;
  itemPublicTokenExchange?: any;
  institutionsGetById?: any;
  accountsGet?: any;
  transactionsSync?: any;
  accountsBalanceGet?: any;
  transactionsRecurringGet?: any;
  itemWebhookUpdate?: any;
} = {}) {
  return {
    linkTokenCreate: (request: any) => {
      return Promise.resolve({
        data: mockResponses.linkTokenCreate || {
          link_token: 'link-sandbox-test-token',
          expiration: new Date(Date.now() + 3600000).toISOString(),
        },
      });
    },

    itemPublicTokenExchange: (request: any) => {
      return Promise.resolve({
        data: mockResponses.itemPublicTokenExchange || {
          access_token: 'access-sandbox-test-token',
          item_id: 'test-item-id',
        },
      });
    },

    institutionsGetById: (request: any) => {
      return Promise.resolve({
        data: mockResponses.institutionsGetById || {
          institution: {
            institution_id: 'ins_test',
            name: 'Test Bank',
            products: ['transactions'],
            country_codes: ['US'],
            logo: 'data:image/png;base64,test',
            primary_color: '#003366',
            url: 'https://test-bank.com',
          },
        },
      });
    },

    accountsGet: (request: any) => {
      return Promise.resolve({
        data: mockResponses.accountsGet || {
          accounts: [
            {
              account_id: 'test-account-1',
              balances: {
                available: 1000,
                current: 1000,
                iso_currency_code: 'USD',
              },
              mask: '0000',
              name: 'Test Checking',
              official_name: 'Test Checking Account',
              type: 'depository',
              subtype: 'checking',
            },
          ],
          item: {
            item_id: 'test-item-id',
            institution_id: 'ins_test',
          },
        },
      });
    },

    transactionsSync: (request: any) => {
      return Promise.resolve({
        data: mockResponses.transactionsSync || {
          added: [],
          modified: [],
          removed: [],
          next_cursor: 'test-cursor',
          has_more: false,
        },
      });
    },

    accountsBalanceGet: (request: any) => {
      return Promise.resolve({
        data: mockResponses.accountsBalanceGet || {
          accounts: [
            {
              account_id: 'test-account-1',
              balances: {
                available: 1000,
                current: 1000,
                iso_currency_code: 'USD',
              },
            },
          ],
        },
      });
    },

    transactionsRecurringGet: (request: any) => {
      return Promise.resolve({
        data: mockResponses.transactionsRecurringGet || {
          inflow_streams: [],
          outflow_streams: [],
        },
      });
    },

    itemWebhookUpdate: (request: any) => {
      return Promise.resolve({
        data: mockResponses.itemWebhookUpdate || {
          item: {
            item_id: request.item_id || 'test-item-id',
            webhook: request.webhook,
          },
        },
      });
    },
  };
}

/**
 * Generates a real JWT token for testing
 * Requires SUPABASE_JWT_SECRET environment variable
 */
export async function createTestJWT(options: {
  userId?: string;
  role?: string;
  expiresIn?: number;
} = {}): Promise<string> {
  const {
    userId = 'test-user-id',
    role = 'authenticated',
    expiresIn = 3600,
  } = options;

  // Import JWT library
  const { create } = await import("https://deno.land/x/djwt@v2.8/mod.ts");

  const secret = Deno.env.get('SUPABASE_JWT_SECRET') || 'test-secret-key';

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const now = Math.floor(Date.now() / 1000);

  const jwt = await create(
    { alg: "HS256", typ: "JWT" },
    {
      sub: userId,
      role: role,
      aud: "authenticated",
      exp: now + expiresIn,
      iat: now,
    },
    key
  );

  return `Bearer ${jwt}`;
}

/**
 * Creates a mock webhook signature for testing Plaid webhooks
 */
export async function createMockWebhookSignature(options: {
  payload?: any;
  expired?: boolean;
  invalidSignature?: boolean;
  tamperedBody?: boolean;
} = {}): Promise<{ signature: string; body: string }> {
  const { payload, expired = false, invalidSignature = false, tamperedBody = false } = options;

  const body = JSON.stringify(
    tamperedBody ? { ...payload, __tampered: true } : payload
  );

  const now = Math.floor(Date.now() / 1000);
  const issuedAt = expired ? now - 400 : now; // >5 min if expired

  const webhookKey = invalidSignature
    ? 'wrong-verification-key'
    : (Deno.env.get('PLAID_WEBHOOK_VERIFICATION_KEY') || 'test-webhook-key');

  // Import JWT library
  const { create } = await import("https://deno.land/x/djwt@v2.8/mod.ts");

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(webhookKey),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  // Calculate SHA-256 hash of body
  const bodyHash = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(body)
  );
  const bodyHashBase64 = btoa(String.fromCharCode(...new Uint8Array(bodyHash)));

  const token = await create(
    { alg: "HS256", typ: "JWT" },
    {
      request_body_sha256: bodyHashBase64,
      iat: issuedAt,
    },
    key
  );

  return { signature: token, body };
}

/**
 * Loads a test fixture from the fixtures directory
 */
export async function loadFixture<T = any>(name: string): Promise<T> {
  const path = new URL(`./fixtures/${name}.json`, import.meta.url);
  try {
    const content = await Deno.readTextFile(path);
    return JSON.parse(content);
  } catch (error) {
    throw new Error(`Failed to load fixture '${name}': ${(error as Error).message}`);
  }
}

/**
 * Helper to create mock transaction data
 */
export function createMockTransaction(overrides: Partial<any> = {}) {
  return {
    transaction_id: 'plaid_tx_' + crypto.randomUUID(),
    account_id: 'plaid_acc_1',
    amount: 10.00,
    date: new Date().toISOString().split('T')[0],
    name: 'Test Transaction',
    merchant_name: 'Test Merchant',
    pending: false,
    category: ['Test', 'Category'],
    category_id: '12345',
    payment_channel: 'online',
    ...overrides,
  };
}

/**
 * Helper to create mock account data
 */
export function createMockAccount(overrides: Partial<any> = {}) {
  return {
    account_id: 'plaid_acc_' + crypto.randomUUID(),
    name: 'Test Checking',
    official_name: 'Test Checking Account',
    type: 'depository',
    subtype: 'checking',
    mask: '0000',
    balances: {
      available: 1000,
      current: 1000,
      iso_currency_code: 'USD',
    },
    ...overrides,
  };
}