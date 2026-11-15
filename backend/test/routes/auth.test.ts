import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import type { Server } from "node:http";

// config reads the environment at import, so it is set before the import. Every
// request here is rejected before the database is reached.
process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test-secret";
process.env.GEMMA_API_KEY = "test-key";
const { createApp } = await import("../../src/app.js");

let server: Server;
let baseUrl = "";

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
  const address = server.address();
  baseUrl = `http://127.0.0.1:${typeof address === "object" && address !== null ? address.port : 0}/api/v1`;
});

after(() => server.close());

async function call(method: string, path: string, options: { body?: unknown; token?: string | undefined } = {}) {
  const init: RequestInit = {
    method,
    headers: { "Content-Type": "application/json", ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}) },
  };
  if (options.body !== undefined) {
    init.body = JSON.stringify(options.body);
  }
  const response = await fetch(`${baseUrl}${path}`, init);
  return { status: response.status, body: (await response.json()) as { error?: { code: string; message: string; fields: Record<string, string> } } };
}

test("rejectsARegistrationWithMissingFieldsAndSaysWhichOnes", async () => {
  const { status, body } = await call("POST", "/auth/register", { body: { name: " ", phone: "", password: "123" } });
  assert.equal(status, 400);
  assert.equal(body.error?.code, "VALIDATION_FAILED");
  assert.deepEqual(Object.keys(body.error?.fields ?? {}).sort(), ["name", "password", "phone"]);
});

test("rejectsARegistrationWithANumberThatIsNotAnIndonesianMobile", async () => {
  const { status, body } = await call("POST", "/auth/register", { body: { name: "Bu Sari", phone: "021 1234567", password: "warung123" } });
  assert.deepEqual([status, body.error?.fields.phone], [400, "Nomor HP tidak valid"]);
});

test("answersAnUnknownNumberWithTheSameMessageAsAWrongPassword", async () => {
  const { status, body } = await call("POST", "/auth/login", { body: { phone: "nomor saya", password: "warung123" } });
  assert.deepEqual([status, body.error?.code, body.error?.message], [401, "UNAUTHORIZED", "Nomor HP atau kata sandi salah"]);
});

test("refusesTheAccountAndConsentRoutesWithoutAValidToken", async () => {
  for (const [method, path, token] of [["GET", "/auth/me", undefined], ["GET", "/auth/me", "forged.token.here"], ["POST", "/auth/consent", undefined]] as const) {
    const { status, body } = await call(method, path, { token });
    assert.deepEqual([status, body.error?.code], [401, "UNAUTHORIZED"], `${method} ${path} ${token}`);
  }
});

test("locksANumberAfterFiveWrongTriesAndSaysWhenToTryAgain", async () => {
  const body = { phone: "bukan nomor 2", password: "warung123" };
  for (let attempt = 0; attempt < 5; attempt++) {
    assert.equal((await call("POST", "/auth/login", { body })).status, 401);
  }
  const locked = await call("POST", "/auth/login", { body });
  assert.deepEqual(
    [locked.status, locked.body.error?.code, locked.body.error?.message],
    [429, "TOO_MANY_ATTEMPTS", "Terlalu banyak percobaan. Coba lagi dalam 15 menit."],
  );
});
