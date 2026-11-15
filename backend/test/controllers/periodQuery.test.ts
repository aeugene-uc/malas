import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import type { Server } from "node:http";

process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test-secret";
process.env.GEMMA_API_KEY = "test-key";
const { readPeriodQuery } = await import("../../src/controllers/analyticsController.js");
const { createApp } = await import("../../src/app.js");

test("readsThePeriodAndItsStartAsF7SendsThem", () => {
  assert.deepEqual(readPeriodQuery({ query: { period: "bulan", from: "2026-11-01" } }), { period: "bulan", start: "2026-11-01" });
});

test("rejectsAnUnknownPeriodOrAStartThatIsNotARealDay", () => {
  assert.throws(() => readPeriodQuery({ query: { period: "hari", from: "2026-11-01" } }), /minggu, bulan atau tahun/);
  assert.throws(() => readPeriodQuery({ query: { period: "bulan", from: "2026-02-30" } }), /Tanggal tidak valid/);
  assert.throws(() => readPeriodQuery({ query: { period: "bulan" } }), /Tanggal tidak valid/);
});

let server: Server;
before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
});
after(() => server.close());

test("refusesBerandaAndAnalisisWithoutSigningIn", async () => {
  const port = (server.address() as { port: number }).port;
  for (const path of ["/home", "/analytics/summary?period=bulan&from=2026-11-01", "/analytics/by-item", "/analytics/by-category", "/alerts"]) {
    const response = await fetch(`http://127.0.0.1:${port}/api/v1${path}`);
    assert.equal(response.status, 401, path);
  }
});
