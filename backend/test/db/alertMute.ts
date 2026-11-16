import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { randomInt } from "node:crypto";
import type { Server } from "node:http";
import { createApp } from "../../src/app.js";
import { config } from "../../src/config.js";
import { prisma } from "../../src/db.js";
import { fixedCategoryRows } from "../../src/services/categories.js";
import { signToken } from "../../src/services/token.js";

// "Jangan ingatkan" (§7.7) through PATCH /alerts/:id on real rows. Runs with
// `npm run test:db`; seeds two owners and deletes them.

type Owner = { userId: string; storeId: string; token: string };

let server: Server;
let baseUrl = "";
let owner: Owner;
let stranger: Owner;

before(async () => {
  owner = await createOwner();
  stranger = await createOwner();
  server = createApp().listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
  baseUrl = `http://127.0.0.1:${(server.address() as { port: number }).port}/api/v1`;
});

after(async () => {
  server.close();
  await prisma.user.deleteMany({ where: { id: { in: [owner?.userId, stranger?.userId].filter((id): id is string => id !== undefined) } } });
  await prisma.$disconnect();
});

test("mutingAnAlertTakesItOffTheListAndMarkingItSeenKeepsIt", async () => {
  const gula = await prisma.alert.create({ data: { storeId: owner.storeId, rule: "PRICE_RISE", value: "Harga Gula naik 10%" } });
  const due = await prisma.alert.create({ data: { storeId: owner.storeId, rule: "DUE_TODAY", value: "Piutang Pak Budi jatuh tempo hari ini" } });
  const muted = await send(owner, "PATCH", `/alerts/${gula.id}`, { muted: true });
  const seen = await send(owner, "PATCH", `/alerts/${due.id}`, { seen: true });
  const listed = (await send(owner, "GET", "/alerts")).body.alerts as { id: string }[];
  assert.deepEqual([muted.status, (muted.body.alert as { muted: boolean }).muted, (seen.body.alert as { seen: boolean }).seen], [200, true, true]);
  assert.deepEqual(listed.map((alert) => alert.id), [due.id]);
});

test("answersAnotherStoresAlertAsNotFoundAndLeavesIt", async () => {
  const alert = await prisma.alert.create({ data: { storeId: owner.storeId, rule: "PRICE_RISE", value: "x" } });
  const reply = await send(stranger, "PATCH", `/alerts/${alert.id}`, { muted: true });
  const untouched = await prisma.alert.findUniqueOrThrow({ where: { id: alert.id } });
  assert.deepEqual([reply.status, untouched.muted], [404, false]);
});

async function send(sendOwner: Owner, method: string, path: string, body?: unknown): Promise<{ status: number; body: Record<string, unknown> }> {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${sendOwner.token}` },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: (await response.json()) as Record<string, unknown> };
}

async function createOwner(): Promise<Owner> {
  const user = await prisma.user.create({
    data: {
      // 0899 is not a real Indonesian prefix, so a test owner can never take a real number.
      phone: `+62899${randomInt(10_000_000, 100_000_000)}`,
      passwordHash: "not-a-password",
      name: "Alert Warung",
      consentAt: new Date(),
      stores: { create: { name: "Alert Warung", businessTypes: ["JUALAN_BARANG"], closedDays: [], categories: { create: fixedCategoryRows() } } },
    },
    select: { id: true, stores: { select: { id: true } } },
  });
  const storeId = user.stores[0]?.id ?? "";
  return { userId: user.id, storeId, token: signToken({ userId: user.id, storeId }, { secret: config.jwtSecret, nowSeconds: Math.floor(Date.now() / 1000) }) };
}
