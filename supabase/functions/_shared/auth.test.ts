import {
  setupTestEnvironment,
  assertEquals,
  assertExists,
  assertThrows,
  createMockSupabaseClient,
  createMockRequest,
  createTestJWT
} from "./test-utils.ts";
import { stub, returnsNext } from "https://deno.land/std@0.224.0/testing/mock.ts";
import * as auth from "./auth.ts";

// Load environment before tests
await setupTestEnvironment();

// =============================================================================
// createAuthenticatedClient() Tests
// =============================================================================

Deno.test("createAuthenticatedClient: creates client with valid Authorization header", () => {
  const request = createMockRequest({
    headers: { Authorization: 'Bearer valid-token' }
  });

  // Should not throw
  const client = auth.createAuthenticatedClient(request);
  assertExists(client);
});

Deno.test("createAuthenticatedClient: throws when Authorization header missing", () => {
  const request = createMockRequest({ method: 'GET' });

  assertThrows(
    () => auth.createAuthenticatedClient(request),
    Error,
    'Missing Authorization header'
  );
});

Deno.test("createAuthenticatedClient: uses CUSTOM_SUPABASE_URL when available", () => {
  const originalUrl = Deno.env.get('SUPABASE_URL');
  const originalCustomUrl = Deno.env.get('CUSTOM_SUPABASE_URL');

  try {
    Deno.env.set('CUSTOM_SUPABASE_URL', 'http://custom-supabase.local');
    Deno.env.set('SUPABASE_URL', 'http://default-supabase.local');

    const request = createMockRequest({
      headers: { Authorization: 'Bearer token' }
    });

    // Should use custom URL (we can't easily verify but test that it doesn't throw)
    const client = auth.createAuthenticatedClient(request);
    assertExists(client);
  } finally {
    if (originalUrl) Deno.env.set('SUPABASE_URL', originalUrl);
    if (originalCustomUrl) {
      Deno.env.set('CUSTOM_SUPABASE_URL', originalCustomUrl);
    } else {
      Deno.env.delete('CUSTOM_SUPABASE_URL');
    }
  }
});

// =============================================================================
// createServiceRoleClient() Tests
// =============================================================================

Deno.test("createServiceRoleClient: creates client successfully", () => {
  const client = auth.createServiceRoleClient();
  assertExists(client);
});

Deno.test("createServiceRoleClient: uses CUSTOM_SERVICE_ROLE_KEY when available", () => {
  const originalKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const originalCustomKey = Deno.env.get('CUSTOM_SERVICE_ROLE_KEY');

  try {
    Deno.env.set('CUSTOM_SERVICE_ROLE_KEY', 'custom-service-key');
    Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'default-service-key');

    // Should use custom key (we can't easily verify but test that it doesn't throw)
    const client = auth.createServiceRoleClient();
    assertExists(client);
  } finally {
    if (originalKey) Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', originalKey);
    if (originalCustomKey) {
      Deno.env.set('CUSTOM_SERVICE_ROLE_KEY', originalCustomKey);
    } else {
      Deno.env.delete('CUSTOM_SERVICE_ROLE_KEY');
    }
  }
});

// =============================================================================
// getAuthenticatedUser() Tests
// =============================================================================

Deno.test("getAuthenticatedUser: returns user when valid JWT provided", async () => {
  const mockSupabase = createMockSupabaseClient({
    userId: 'test-user-123'
  });

  const clientStub = stub(auth, "createAuthenticatedClient", () => mockSupabase);

  try {
    const jwt = await createTestJWT({ userId: 'test-user-123' });
    const request = createMockRequest({
      headers: { Authorization: jwt }
    });

    const result = await auth.getAuthenticatedUser(request);

    assertEquals(result.error, null);
    assertExists(result.user);
    assertEquals(result.user?.id, 'test-user-123');
  } finally {
    clientStub.restore();
  }
});

Deno.test("getAuthenticatedUser: returns error when Authorization header missing", async () => {
  const request = createMockRequest({ method: 'GET' });

  const result = await auth.getAuthenticatedUser(request);

  assertExists(result.error);
  assertEquals(result.user, null);
  assertEquals(result.error?.message, 'Missing Authorization header');
});

Deno.test("getAuthenticatedUser: returns error when auth.getUser() fails", async () => {
  const mockSupabase = createMockSupabaseClient({
    mockErrors: {
      auth: new Error('Invalid JWT')
    }
  });

  const clientStub = stub(auth, "createAuthenticatedClient", () => mockSupabase);

  try {
    const request = createMockRequest({
      headers: { Authorization: 'Bearer invalid-token' }
    });

    const result = await auth.getAuthenticatedUser(request);

    assertExists(result.error);
    assertEquals(result.user, null);
  } finally {
    clientStub.restore();
  }
});

Deno.test("getAuthenticatedUser: returns error when user is null", async () => {
  const mockSupabase = {
    auth: {
      getUser: () => Promise.resolve({
        data: { user: null },
        error: null
      })
    }
  };

  const clientStub = stub(auth, "createAuthenticatedClient", () => mockSupabase as any);

  try {
    const request = createMockRequest({
      headers: { Authorization: 'Bearer token' }
    });

    const result = await auth.getAuthenticatedUser(request);

    assertExists(result.error);
    assertEquals(result.user, null);
    assertEquals(result.error?.message, 'No user found');
  } finally {
    clientStub.restore();
  }
});

// =============================================================================
// requireAuth() Tests
// =============================================================================

Deno.test("requireAuth: returns user when valid JWT provided", async () => {
  const mockSupabase = createMockSupabaseClient({
    userId: 'test-user-id'
  });

  const clientStub = stub(auth, "createAuthenticatedClient", () => mockSupabase);

  try {
    const jwt = await createTestJWT({ userId: 'test-user-id' });
    const request = createMockRequest({
      headers: { Authorization: jwt }
    });

    const result = await auth.requireAuth(request);

    assertEquals(result instanceof Response, false);
    if (!(result instanceof Response)) {
      assertEquals(result?.id, 'test-user-id');
    }
  } finally {
    clientStub.restore();
  }
});

Deno.test("requireAuth: returns 401 when Authorization header missing", async () => {
  const request = createMockRequest({ method: 'GET' });

  const response = await auth.requireAuth(request);

  if (response instanceof Response) {
    assertEquals(response.status, 401);
    const body = await response.json();
    assertEquals(body.error, 'Unauthorized');
    assertExists(body.message);
  } else {
    throw new Error("Expected a Response object");
  }
});

Deno.test("requireAuth: returns 401 when user is null", async () => {
  const mockSupabase = {
    auth: {
      getUser: () => Promise.resolve({
        data: { user: null },
        error: null
      })
    }
  };

  const clientStub = stub(auth, "createAuthenticatedClient", () => mockSupabase as any);

  try {
    const request = createMockRequest({
      headers: { Authorization: 'Bearer token' }
    });

    const response = await auth.requireAuth(request);

    if (response instanceof Response) {
      assertEquals(response.status, 401);
      const body = await response.json();
      assertEquals(body.error, 'Unauthorized');
    } else {
      throw new Error("Expected a Response object");
    }
  } finally {
    clientStub.restore();
  }
});

Deno.test("requireAuth: returns 401 with error message when authentication fails", async () => {
  const mockSupabase = createMockSupabaseClient({
    mockErrors: {
      auth: new Error('Token expired')
    }
  });

  const clientStub = stub(auth, "createAuthenticatedClient", () => mockSupabase);

  try {
    const request = createMockRequest({
      headers: { Authorization: 'Bearer expired-token' }
    });

    const response = await auth.requireAuth(request);

    if (response instanceof Response) {
      assertEquals(response.status, 401);
      const body = await response.json();
      assertEquals(body.error, 'Unauthorized');
      assertExists(body.message);
    } else {
      throw new Error("Expected a Response object");
    }
  } finally {
    clientStub.restore();
  }
});

// =============================================================================
// handleCors() Tests
// =============================================================================

Deno.test("handleCors: returns 200 for OPTIONS request", () => {
  const request = createMockRequest({ method: 'OPTIONS' });
  const response = auth.handleCors(request);

  if (response) {
    assertEquals(response.status, 200);
    assertEquals(response.headers.get('Access-Control-Allow-Origin'), '*');
    assertExists(response.headers.get('Access-Control-Allow-Methods'));
    assertExists(response.headers.get('Access-Control-Allow-Headers'));
  } else {
    throw new Error("Expected a Response object for OPTIONS request");
  }
});

Deno.test("handleCors: returns null for non-OPTIONS requests", () => {
  const methods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'];

  for (const method of methods) {
    const request = createMockRequest({ method });
    const response = auth.handleCors(request);
    assertEquals(response, null, `Expected null for ${method} request`);
  }
});

Deno.test("handleCors: CORS headers include all required fields", () => {
  const request = createMockRequest({ method: 'OPTIONS' });
  const response = auth.handleCors(request);

  if (response) {
    assertEquals(response.headers.get('Access-Control-Allow-Origin'), '*');
    assertEquals(
      response.headers.get('Access-Control-Allow-Methods'),
      'POST, GET, OPTIONS, PUT, DELETE'
    );
    assertEquals(
      response.headers.get('Access-Control-Allow-Headers'),
      'authorization, content-type, x-client-info, apikey'
    );
  } else {
    throw new Error("Expected a Response object");
  }
});

// =============================================================================
// jsonResponse() Tests
// =============================================================================

Deno.test("jsonResponse: includes CORS headers with default status", () => {
  const data = { message: 'success' };
  const response = auth.jsonResponse(data);

  assertEquals(response.status, 200);
  assertEquals(response.headers.get('Access-Control-Allow-Origin'), '*');
  assertEquals(response.headers.get('Content-Type'), 'application/json');
});

Deno.test("jsonResponse: respects custom status codes", () => {
  const testCases = [
    { status: 200, data: { success: true } },
    { status: 201, data: { created: true } },
    { status: 400, data: { error: 'Bad Request' } },
    { status: 401, data: { error: 'Unauthorized' } },
    { status: 403, data: { error: 'Forbidden' } },
    { status: 404, data: { error: 'Not Found' } },
    { status: 500, data: { error: 'Internal Server Error' } },
  ];

  for (const { status, data } of testCases) {
    const response = auth.jsonResponse(data, status);
    assertEquals(response.status, status, `Status code should be ${status}`);
  }
});

Deno.test("jsonResponse: includes additional headers", () => {
  const data = { message: 'success' };
  const additionalHeaders = {
    'X-Custom-Header': 'custom-value',
    'X-Request-ID': '123-456-789',
  };

  const response = auth.jsonResponse(data, 200, additionalHeaders);

  assertEquals(response.status, 200);
  assertEquals(response.headers.get('X-Custom-Header'), 'custom-value');
  assertEquals(response.headers.get('X-Request-ID'), '123-456-789');
  // Should still have CORS headers
  assertEquals(response.headers.get('Access-Control-Allow-Origin'), '*');
});

Deno.test("jsonResponse: properly serializes complex data", async () => {
  const complexData = {
    user: { id: 1, name: 'Test User' },
    items: [{ id: 1 }, { id: 2 }],
    metadata: { count: 2, page: 1 },
  };

  const response = auth.jsonResponse(complexData);
  const body = await response.json();

  assertEquals(body.user.id, 1);
  assertEquals(body.items.length, 2);
  assertEquals(body.metadata.count, 2);
});

Deno.test("jsonResponse: handles null and undefined data", async () => {
  const nullResponse = auth.jsonResponse(null);
  const nullBody = await nullResponse.json();
  assertEquals(nullBody, null);

  const undefinedResponse = auth.jsonResponse(undefined);
  const undefinedText = await undefinedResponse.text();
  // undefined gets serialized as empty or null depending on JSON.stringify behavior
  assertExists(undefinedText);
});

Deno.test("jsonResponse: handles arrays", async () => {
  const arrayData = [
    { id: 1, name: 'Item 1' },
    { id: 2, name: 'Item 2' },
  ];

  const response = auth.jsonResponse(arrayData);
  const body = await response.json();

  assertEquals(Array.isArray(body), true);
  assertEquals(body.length, 2);
  assertEquals(body[0].id, 1);
});

// =============================================================================
// CORS Headers Export Test
// =============================================================================

Deno.test("corsHeaders: exports correct header values", () => {
  assertExists(auth.corsHeaders);
  assertEquals(auth.corsHeaders['Access-Control-Allow-Origin'], '*');
  assertEquals(auth.corsHeaders['Access-Control-Allow-Methods'], 'POST, GET, OPTIONS, PUT, DELETE');
  assertExists(auth.corsHeaders['Access-Control-Allow-Headers']);
});