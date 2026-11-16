import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import type { Server } from "node:http";
import { createApp } from "../../src/app.js";
import { config } from "../../src/config.js";
import { prisma } from "../../src/db.js";
import { resolveBusinessDate } from "../../src/services/businessDate.js";
import { fixedCategoryRows } from "../../src/services/categories.js";
import { signToken } from "../../src/services/token.js";

// S5 Simpan end to end, through the route, on real rows: name resolution, §10
// recompute, discount, the soft warnings and idempotency. Needs a database, so
// it runs with `npm run test:db`. It seeds its own two owners and deletes them.

type Owner = { userId: string; storeId: string; token: string; categoryIdByKey: Map<string, string> };
type SaveReply = {
  status: number;
  body: {
    transaction: {
      id: string;
      businessDate: string;
      total: number;
      paid: number;
      remaining: number;
      person: { id: string; name: string } | null;
      lines: { id: string; item: { id: string; name: string } | null; category: { id: string; name: string } | null; quantity: string | null; unitPrice: number | null; lineTotal: number; discount: number; isNew: boolean }[];
    };
    warnings: { code: string; lineId?: string; transactionId?: string }[];
    error?: { code: string; fields: Record<string, string> };
  };
};

let server: Server;
let baseUrl = "";
let owner: Owner;
let otherOwner: Owner;
let today = "";

before(async () => {
  owner = await createOwner("S5 Warung");
  otherOwner = await createOwner("S5 Tetangga");
  today = resolveBusinessDate({ now: new Date(), timezone: "Asia/Jakarta", dayChangeHour: 4 });
  server = createApp().listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
  baseUrl = `http://127.0.0.1:${(server.address() as { port: number }).port}/api/v1`;
});

after(async () => {
  server.close();
  await prisma.user.deleteMany({ where: { id: { in: [owner?.userId, otherOwner?.userId].filter((id): id is string => id !== undefined) } } });
  await prisma.$disconnect();
});

test("savesSpokenTotalAndRecordsDiscountThenCreatesTheItemAsBaru", async () => {
  // "nasi 2, 25 ribu aja" (spec §7.3), on a day nothing else is saved.
  const reply = await save(owner, {
    businessDate: "2026-10-01",
    direction: "IN",
    total: 25000,
    lines: [{ itemId: null, itemName: "Nasi Uduk", categoryId: null, quantity: "2", unit: "porsi", unitPrice: 15000, lineTotal: 25000 }],
    payments: [{ date: "2026-10-01", amount: 25000, label: "cash" }],
  });
  const line = reply.body.transaction.lines[0];
  assert.equal(reply.status, 201);
  assert.deepEqual([line?.lineTotal, line?.discount, line?.isNew, line?.item?.name, line?.category?.name], [25000, 5000, true, "Nasi Uduk", "Penjualan"]);
  assert.deepEqual(reply.body.warnings, []);
  const item = await prisma.item.findFirstOrThrow({ where: { storeId: owner.storeId, normalisedName: "nasi uduk" } });
  assert.deepEqual([item.kind, item.savedPrice, item.unit], ["SOLD", 15000, "porsi"]);
});

test("matchesAKnownNameSilentlyFillsItsPriceAndAddsItToTheTotal", async () => {
  await prisma.item.create({ data: { storeId: owner.storeId, name: "Es teh", normalisedName: "es teh", kind: "SOLD", savedPrice: 5000, categoryId: categoryId(owner, "IN:Penjualan") } });
  // The app sends what it knows: no price, so total 0 (#260).
  const reply = await save(owner, {
    businessDate: "2026-10-02",
    direction: "IN",
    total: 0,
    lines: [{ itemId: null, itemName: "  ES  TEH ", categoryId: null, quantity: "3", unit: null, unitPrice: null, lineTotal: null }],
    payments: [],
  });
  const line = reply.body.transaction.lines[0];
  assert.deepEqual([reply.body.transaction.total, line?.unitPrice, line?.lineTotal, line?.discount, line?.isNew, line?.item?.name], [15000, 5000, 15000, 0, false, "Es teh"]);
  assert.deepEqual(reply.body.warnings, []);
  assert.equal(await prisma.item.count({ where: { storeId: owner.storeId, normalisedName: "es teh" } }), 1);
});

test("savesALineWithNoPriceAndFlagsItemNoPrice", async () => {
  const reply = await save(owner, {
    businessDate: "2026-10-03",
    direction: "IN",
    total: 0,
    personName: "Pak Budi",
    lines: [{ itemId: null, itemName: "Kerupuk", categoryId: null, quantity: "25", unit: null, unitPrice: null, lineTotal: null }],
    payments: [],
  });
  const line = reply.body.transaction.lines[0];
  assert.equal(reply.status, 201);
  assert.deepEqual([line?.lineTotal, reply.body.transaction.person?.name], [0, "Pak Budi"]);
  assert.deepEqual(reply.body.warnings, [{ code: "ITEM_NO_PRICE", message: "Harga belum ada", lineId: line?.id }]);
});

test("reusesAPersonByNameAndLeavesAnUnpaidBonAsPiutang", async () => {
  const reply = await save(owner, {
    businessDate: "2026-10-04",
    direction: "IN",
    total: 30000,
    personName: "pak budi",
    lines: [{ itemId: null, itemName: null, categoryId: null, quantity: null, unit: null, unitPrice: null, lineTotal: 30000 }],
    payments: [],
  });
  assert.deepEqual([reply.body.transaction.paid, reply.body.transaction.remaining], [0, 30000]);
  assert.equal(await prisma.person.count({ where: { storeId: owner.storeId } }), 1);
});

test("savesKetiksQuickAmountWithNoDateOnTheStoresToday", async () => {
  const reply = await save(owner, {
    direction: "IN",
    total: 1200000,
    source: "TYPED",
    lines: [{ itemId: null, itemName: null, categoryId: categoryId(owner, "IN:Penjualan"), quantity: null, unit: null, unitPrice: null, lineTotal: 1200000 }],
    payments: [{ date: today, amount: 1200000, label: "cash" }],
  });
  assert.deepEqual([reply.status, reply.body.transaction.businessDate, reply.body.transaction.remaining], [201, today, 0]);
});

test("takesAPrintedTotalBelowTheLinesAsADiscountAndFlagsTheMismatch", async () => {
  const reply = await save(owner, {
    businessDate: "2026-10-05",
    direction: "OUT",
    total: 45000,
    personName: "Toko A",
    lines: [
      { itemId: null, itemName: "Gula", categoryId: categoryId(owner, "OUT:Bahan"), quantity: "2", unit: "kg", unitPrice: 15000, lineTotal: 30000 },
      { itemId: null, itemName: "Minyak", categoryId: categoryId(owner, "OUT:Bahan"), quantity: "1", unit: "liter", unitPrice: 18000, lineTotal: 18000 },
    ],
    payments: [{ date: "2026-10-05", amount: 45000, label: "cash" }],
  });
  const [gula, minyak] = reply.body.transaction.lines;
  assert.deepEqual([reply.body.transaction.total, gula?.lineTotal, minyak?.lineTotal, minyak?.discount], [45000, 30000, 15000, 3000]);
  assert.deepEqual(reply.body.warnings.map((warning) => warning.code), ["TOTAL_MISMATCH"]);
});

test("flagsAPriceTenTimesTheSavedOneAndKeepsTheSavedPrice", async () => {
  const reply = await save(owner, {
    businessDate: "2026-10-06",
    direction: "OUT",
    total: 150000,
    lines: [{ itemId: null, itemName: "gula", categoryId: null, quantity: "1", unit: "kg", unitPrice: 150000, lineTotal: null }],
    payments: [],
  });
  assert.deepEqual(reply.body.warnings.map((warning) => warning.code), ["PRICE_IMPLAUSIBLE"]);
  assert.equal(reply.body.transaction.lines[0]?.category?.name, "Bahan");
  const gula = await prisma.item.findFirstOrThrow({ where: { storeId: owner.storeId, normalisedName: "gula", kind: "BOUGHT" } });
  assert.equal(gula.savedPrice, 15000);
});

test("remembersTheLastPriceUsed", async () => {
  await save(owner, {
    businessDate: "2026-10-07",
    direction: "OUT",
    total: 16000,
    lines: [{ itemId: null, itemName: "Gula", categoryId: null, quantity: "1", unit: "kg", unitPrice: 16000, lineTotal: null }],
    payments: [{ date: "2026-10-07", amount: 16000, label: "cash" }],
  });
  const gula = await prisma.item.findFirstOrThrow({ where: { storeId: owner.storeId, normalisedName: "gula", kind: "BOUGHT" } });
  assert.equal(gula.savedPrice, 16000);
});

test("savesAnOverpaymentAndFlagsKembalikan", async () => {
  const reply = await save(owner, {
    businessDate: "2026-10-08",
    direction: "OUT",
    total: 100000,
    lines: [{ itemId: null, itemName: null, categoryId: categoryId(owner, "OUT:Sewa"), quantity: null, unit: null, unitPrice: null, lineTotal: 100000 }],
    payments: [{ date: "2026-10-08", amount: 120000, label: "transfer" }],
  });
  assert.deepEqual([reply.body.transaction.remaining, reply.body.warnings.map((warning) => warning.code)], [-20000, ["OVERPAID"]]);
});

test("warnsOfADuplicateWithTheSameDateDirectionAndTotal", async () => {
  const entry = { businessDate: "2026-10-09", direction: "OUT", total: 77000, lines: [{ itemId: null, itemName: null, categoryId: null, quantity: null, unit: null, unitPrice: null, lineTotal: 77000 }], payments: [] };
  const first = await save(owner, entry);
  const second = await save(owner, entry);
  assert.deepEqual(second.body.warnings, [{ code: "DUPLICATE_SUSPECTED", message: "Sepertinya catatan ini sudah ada", transactionId: first.body.transaction.id }]);
});

test("warnsWhenALumpSumSaleMeetsAnItemisedSaleOnTheSameDay", async () => {
  await save(owner, {
    businessDate: "2026-10-10",
    direction: "IN",
    total: 10000,
    lines: [{ itemId: null, itemName: "Es teh", categoryId: null, quantity: "2", unit: null, unitPrice: 5000, lineTotal: null }],
    payments: [{ date: "2026-10-10", amount: 10000, label: "cash" }],
  });
  const lumpSum = await save(owner, {
    businessDate: "2026-10-10",
    direction: "IN",
    total: 500000,
    lines: [{ itemId: null, itemName: null, categoryId: null, quantity: null, unit: null, unitPrice: null, lineTotal: 500000 }],
    payments: [{ date: "2026-10-10", amount: 500000, label: "cash" }],
  });
  assert.deepEqual(lumpSum.body.warnings.map((warning) => warning.code), ["LUMP_SUM_WITH_ITEMISED"]);
});

test("replaysARetryWithTheSameKeyInsteadOfSavingTwice", async () => {
  const key = randomUUID();
  const entry = { businessDate: "2026-10-11", direction: "IN", total: 42000, lines: [{ itemId: null, itemName: null, categoryId: null, quantity: null, unit: null, unitPrice: null, lineTotal: 42000 }], payments: [] };
  const first = await save(owner, entry, key);
  const retry = await save(owner, entry, key);
  assert.deepEqual([retry.status, retry.body], [201, first.body]);
  assert.equal(await prisma.transaction.count({ where: { storeId: owner.storeId, total: 42000 } }), 1);
});

test("refusesTheSameKeyWithADifferentBody", async () => {
  const key = randomUUID();
  const entry = { businessDate: "2026-10-12", direction: "IN", total: 43000, lines: [{ itemId: null, itemName: null, categoryId: null, quantity: null, unit: null, unitPrice: null, lineTotal: 43000 }], payments: [] };
  await save(owner, entry, key);
  const changed = await save(owner, { ...entry, total: 44000 }, key);
  assert.deepEqual([changed.status, changed.body.error?.code], [409, "IDEMPOTENCY_CONFLICT"]);
});

test("refusesAFutureDateAnotherStoresCategoryAndACategoryPointingTheOtherWay", async () => {
  const future = await save(owner, { businessDate: "2999-01-01", direction: "IN", total: 1000, lines: [], payments: [] });
  const foreign = await save(owner, {
    businessDate: "2026-10-13",
    direction: "IN",
    total: 1000,
    lines: [{ itemId: null, itemName: null, categoryId: categoryId(otherOwner, "IN:Penjualan"), quantity: null, unit: null, unitPrice: null, lineTotal: 1000 }],
    payments: [],
  });
  assert.deepEqual([future.status, Object.keys(future.body.error?.fields ?? {})], [400, ["businessDate"]]);
  const wrongWay = await save(owner, {
    businessDate: "2026-10-13",
    direction: "OUT",
    total: 1000,
    lines: [{ itemId: null, itemName: null, categoryId: categoryId(owner, "IN:Penjualan"), quantity: null, unit: null, unitPrice: null, lineTotal: 1000 }],
    payments: [],
  });
  assert.deepEqual([foreign.status, Object.keys(foreign.body.error?.fields ?? {})], [400, ["lines.0.categoryId"]]);
  assert.deepEqual([wrongWay.status, Object.keys(wrongWay.body.error?.fields ?? {})], [400, ["lines.0.categoryId"]]);
});

test("savesABareAmountWithNoLinesAsOneLine", async () => {
  const reply = await save(owner, { businessDate: "2026-10-14", direction: "OUT", total: 25000, lines: [], payments: [] });
  const line = reply.body.transaction.lines[0];
  assert.deepEqual([reply.body.transaction.lines.length, line?.lineTotal, line?.category?.name, reply.body.warnings], [1, 25000, "Lainnya", []]);
});

// ---- Helpers ----------------------------------------------------------------

async function save(saveOwner: Owner, entry: Record<string, unknown>, key: string = randomUUID()): Promise<SaveReply> {
  const response = await fetch(`${baseUrl}/transactions`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${saveOwner.token}`, "Idempotency-Key": key },
    body: JSON.stringify({ personId: null, personName: null, dueDate: null, source: "VOICE", inputId: null, note: null, ...entry }),
  });
  return { status: response.status, body: (await response.json()) as SaveReply["body"] };
}

async function createOwner(name: string): Promise<Owner> {
  const user = await prisma.user.create({
    data: {
      // 0899 is not a real Indonesian prefix, so a test owner can never take a real number.
      phone: `+62899${randomInt(10_000_000, 100_000_000)}`,
      passwordHash: "not-a-password",
      name,
      consentAt: new Date(),
      stores: { create: { name, businessTypes: ["MAKANAN_MINUMAN"], closedDays: [], categories: { create: fixedCategoryRows() } } },
    },
    select: { id: true, stores: { select: { id: true, categories: { select: { id: true, name: true, direction: true } } } } },
  });
  const store = user.stores[0];
  if (store === undefined) {
    throw new Error("the test owner was created without a store");
  }
  const token = signToken({ userId: user.id, storeId: store.id }, { secret: config.jwtSecret, nowSeconds: Math.floor(Date.now() / 1000) });
  return { userId: user.id, storeId: store.id, token, categoryIdByKey: new Map(store.categories.map((category) => [`${category.direction}:${category.name}`, category.id])) };
}

function categoryId(categoryOwner: Owner, key: string): string {
  const id = categoryOwner.categoryIdByKey.get(key);
  if (id === undefined) {
    throw new Error(`no category ${key}`);
  }
  return id;
}
