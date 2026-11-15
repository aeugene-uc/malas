import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import type { Server } from "node:http";

// No request here reaches the database: each is refused at sign-in or at the
// store check before any query.
process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test-secret";
process.env.GEMMA_API_KEY = "test-key";
const { createApp } = await import("../../src/app.js");
const { signToken } = await import("../../src/services/token.js");

let server: Server;
let baseUrl = "";
const token = signToken({ userId: "user-1", storeId: "store-1" }, { secret: "test-secret", nowSeconds: Math.floor(Date.now() / 1000) });

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
  baseUrl = `http://127.0.0.1:${(server.address() as { port: number }).port}/api/v1`;
});

after(() => server.close());

test("answersAnotherStoresSettingsAsNotFound", async () => {
  const response = await fetch(`${baseUrl}/stores/store-2`, { headers: { Authorization: `Bearer ${token}` } });
  const body = (await response.json()) as { error: { code: string } };
  assert.deepEqual([response.status, body.error.code], [404, "NOT_FOUND"]);
});

test("refusesEveryCatalogRouteWithoutSigningIn", async () => {
  for (const [method, path] of [
    ["GET", "/stores/store-1"],
    ["PATCH", "/stores/store-1"],
    ["GET", "/items"],
    ["POST", "/items"],
    ["PATCH", "/items/item-1"],
    ["DELETE", "/items/item-1"],
    ["GET", "/people"],
    ["POST", "/people"],
    ["GET", "/categories"],
    ["DELETE", "/categories/category-1"],
  ] as const) {
    const response = await fetch(`${baseUrl}${path}`, { method, headers: { "Content-Type": "application/json" }, ...(method === "GET" ? {} : { body: "{}" }) });
    assert.equal(response.status, 401, `${method} ${path}`);
  }
});
