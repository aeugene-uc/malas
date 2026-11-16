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

// S6 Catatan through the routes, on real rows: the list and its filters, edit
// with history, Bayar, Piutang/Utang, Ulangi, Retur and a loan's Utang. Runs
// with `npm run test:db`; each test seeds its own owner and all are deleted.

type Owner = { userId: string; storeId: string; token: string; categoryIdByKey: Map<string, string> };
type Row = {
  id: string;
  businessDate: string;
  direction: "IN" | "OUT";
  total: number;
  dueDate: string | null;
  paid: number;
  remaining: number;
  editCount: number;
  hasRetur: boolean;
  person: { id: string; name: string } | null;
  lines: { id: string; item: { id: string; name: string } | null; category: { id: string; name: string } | null; quantity: string | null; lineTotal: number }[];
};
type Reply = { status: number; body: Record<string, unknown> };

let server: Server;
let baseUrl = "";
let today = "";
const owners: Owner[] = [];

before(async () => {
  today = resolveBusinessDate({ now: new Date(), timezone: "Asia/Jakarta", dayChangeHour: 4 });
  server = createApp().listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
  baseUrl = `http://127.0.0.1:${(server.address() as { port: number }).port}/api/v1`;
});

after(async () => {
  server.close();
  await prisma.user.deleteMany({ where: { id: { in: owners.map((owner) => owner.userId) } } });
  await prisma.$disconnect();
});

test("listsNewestFirstAndFiltersByDirectionUnpaidSearchItemAndCategory", async () => {
  const owner = await createOwner();
  const esTeh = await saveEntry(owner, { businessDate: "2026-10-01", direction: "IN", total: 10000, lines: [line({ itemName: "Es teh", quantity: "2", unitPrice: 5000 })], payments: [paid("2026-10-01", 10000)] });
  const bon = await saveEntry(owner, { businessDate: "2026-10-02", direction: "IN", total: 30000, personName: "Pak Budi", lines: [line({ lineTotal: 30000 })], payments: [] });
  const gas = await saveEntry(owner, { businessDate: "2026-10-03", direction: "OUT", total: 25000, lines: [line({ itemName: "Gas", categoryId: categoryId(owner, "OUT:Operasional"), quantity: "1", unitPrice: 25000 })], payments: [paid("2026-10-03", 25000)] });

  assert.deepEqual(await listIds(owner, ""), [gas, bon, esTeh]);
  assert.deepEqual(await listIds(owner, "?direction=IN"), [bon, esTeh]);
  assert.deepEqual(await listIds(owner, "?unpaid=true"), [bon]);
  assert.deepEqual(await listIds(owner, "?q=budi"), [bon]);
  assert.deepEqual(await listIds(owner, "?q=es%20teh"), [esTeh]);
  assert.deepEqual(await listIds(owner, "?q=operasional"), [gas]);
  assert.deepEqual(await listIds(owner, `?categoryId=${categoryId(owner, "OUT:Operasional")}`), [gas]);
  assert.deepEqual(await listIds(owner, "?from=2026-10-02&to=2026-10-02"), [bon]);
  const gasItemId = (await prisma.item.findFirstOrThrow({ where: { storeId: owner.storeId, normalisedName: "gas" } })).id;
  assert.deepEqual(await listIds(owner, `?itemId=${gasItemId}`), [gas]);
  assert.equal((await send(owner, "GET", "/transactions?direction=SIDEWAYS")).status, 400);
});

test("pagesThirtyAtATimeWithACursor", async () => {
  const owner = await createOwner();
  const created = await prisma.transaction.createMany({
    data: Array.from({ length: 31 }, (_, index) => ({ storeId: owner.storeId, businessDate: new Date(Date.UTC(2026, 8, 1 + index)), direction: "IN" as const, total: 1000 + index, source: "TYPED" as const })),
  });
  const first = await send(owner, "GET", "/transactions");
  const firstRows = first.body.transactions as Row[];
  const second = await send(owner, "GET", `/transactions?cursor=${first.body.nextCursor as string}`);
  assert.deepEqual([firstRows.length, firstRows[0]?.total, (second.body.transactions as Row[]).map((row) => row.total), second.body.nextCursor], [30, 1030, [1000], null]);
  assert.equal(created.count, 31);
});

test("editKeepsTheEarlierVersionAndACashSalesPaymentFollowsTheFixedTotal", async () => {
  const owner = await createOwner();
  const id = await saveEntry(owner, { businessDate: "2026-10-05", direction: "IN", total: 100000, lines: [line({ lineTotal: 100000 })], payments: [paid("2026-10-05", 100000)] });
  const edited = await send(owner, "PATCH", `/transactions/${id}`, { businessDate: "2026-10-05", direction: "IN", total: 10000, lines: [line({ lineTotal: 10000 })] });
  const row = (edited.body.transaction as Row);
  assert.deepEqual([edited.status, row.total, row.paid, row.remaining, row.editCount, edited.body.warnings], [200, 10000, 10000, 0, 1, []]);
  const history = (await send(owner, "GET", `/transactions/${id}/history`)).body.history as { previous: { total: number } }[];
  assert.deepEqual(history.map((entry) => entry.previous.total), [100000]);
});

test("anEditBelowWhatWasPaidOnABonTurnsTheExtraIntoKembalikan", async () => {
  const owner = await createOwner();
  const id = await saveEntry(owner, { businessDate: "2026-10-06", direction: "IN", total: 100000, personName: "Bu Ani", lines: [line({ lineTotal: 100000 })], payments: [] });
  await send(owner, "POST", `/transactions/${id}/payments`, { amount: 80000 });
  const edited = await send(owner, "PATCH", `/transactions/${id}`, { businessDate: "2026-10-06", direction: "IN", total: 60000, personName: "Bu Ani", lines: [line({ lineTotal: 60000 })] });
  const payables = (await send(owner, "GET", "/payables")).body.rows as Row[];
  assert.deepEqual([(edited.body.transaction as Row).remaining, (edited.body.warnings as { code: string }[]).map((warning) => warning.code)], [-20000, ["OVERPAID"]]);
  assert.deepEqual(payables.map((row) => [row.id, row.remaining]), [[id, -20000]]);
});

test("bayarRecordsAPartPaymentTodayAndDeletingItReopensTheBalance", async () => {
  const owner = await createOwner();
  const id = await saveEntry(owner, { businessDate: "2026-10-07", direction: "OUT", total: 150000, personName: "Toko A", lines: [line({ lineTotal: 150000 })], payments: [] });
  const bayar = await send(owner, "POST", `/transactions/${id}/payments`, { amount: 50000 });
  const payment = bayar.body.payment as { id: string; date: string; amount: number };
  assert.deepEqual([bayar.status, payment.date, payment.amount, (bayar.body.transaction as Row).remaining], [201, today, 50000, 100000]);
  const removed = await send(owner, "DELETE", `/payments/${payment.id}`);
  const detail = (await send(owner, "GET", `/transactions/${id}`)).body.transaction as Row & { payments: unknown[] };
  assert.deepEqual([removed.status, detail.remaining, detail.payments], [200, 150000, []]);
  assert.equal((await send(owner, "POST", `/transactions/${id}/payments`, { amount: 0 })).status, 400);
});

test("piutangAndUtangHoldOneRowPerOpenEntryDueSoonestFirst", async () => {
  const owner = await createOwner();
  const later = await saveEntry(owner, { businessDate: "2026-10-09", direction: "IN", total: 20000, personName: "A", dueDate: "2026-12-30", lines: [line({ lineTotal: 20000 })], payments: [] });
  const sooner = await saveEntry(owner, { businessDate: "2026-10-08", direction: "IN", total: 30000, personName: "B", dueDate: "2026-12-01", lines: [line({ lineTotal: 30000 })], payments: [] });
  const noDue = await saveEntry(owner, { businessDate: "2026-10-10", direction: "IN", total: 40000, personName: "C", lines: [line({ lineTotal: 15000 }), line({ lineTotal: 25000 })], payments: [] });
  await saveEntry(owner, { businessDate: "2026-10-10", direction: "IN", total: 9000, lines: [line({ lineTotal: 9000 })], payments: [paid("2026-10-10", 9000)] });
  const tempo = await saveEntry(owner, { businessDate: "2026-10-10", direction: "OUT", total: 70000, personName: "Toko A", lines: [line({ lineTotal: 70000 })], payments: [paid("2026-10-10", 20000)] });
  const piutang = (await send(owner, "GET", "/receivables")).body.rows as Row[];
  const utang = (await send(owner, "GET", "/payables")).body.rows as Row[];
  assert.deepEqual(piutang.map((row) => row.id), [sooner, later, noDue]);
  assert.deepEqual(utang.map((row) => [row.id, row.remaining]), [[tempo, 50000]]);
});

test("ulangiCopiesAnEntryToTodayPaidInFullAndABonStaysABon", async () => {
  const owner = await createOwner();
  const es = await saveEntry(owner, { businessDate: "2026-10-11", direction: "OUT", total: 12000, lines: [line({ itemName: "Es batu", quantity: "2", unitPrice: 6000 })], payments: [paid("2026-10-11", 12000)] });
  const bon = await saveEntry(owner, { businessDate: "2026-10-11", direction: "IN", total: 30000, personName: "Pak Budi", lines: [line({ lineTotal: 30000 })], payments: [] });
  const esDraft = ((await send(owner, "POST", `/transactions/${es}/repeat`)).body.drafts as Draft[])[0];
  const bonDraft = ((await send(owner, "POST", `/transactions/${bon}/repeat`)).body.drafts as Draft[])[0];
  assert.deepEqual([esDraft?.businessDate, esDraft?.total, esDraft?.lines[0]?.itemName, esDraft?.lines[0]?.quantity, esDraft?.payments, esDraft?.linkedTransactionId], [today, 12000, "Es batu", "2", [{ date: today, amount: 12000, label: "cash" }], null]);
  assert.deepEqual([bonDraft?.personName, bonDraft?.payments], ["Pak Budi", []]);
  assert.equal(await prisma.transaction.count({ where: { storeId: owner.storeId } }), 2);
});

test("returAgainstAnUnpaidBonLowersThePiutangAndMovesNoCash", async () => {
  const owner = await createOwner();
  const original = await saveEntry(owner, { businessDate: "2026-10-12", direction: "IN", total: 100000, personName: "Pak Budi", lines: [line({ itemName: "Beras", quantity: "10", unit: "kg", unitPrice: 10000 })], payments: [] });
  const draft = ((await send(owner, "POST", `/transactions/${original}/retur`)).body.drafts as Draft[])[0];
  assert.deepEqual([draft?.linkedTransactionId, draft?.lines[0]?.quantity, draft?.lines[0]?.lineTotal, draft?.total, draft?.payments], [original, "-10", -100000, -100000, []]);
  // The owner takes back 4 kg of the 10.
  const retur = await saveEntry(owner, { ...draft, total: -40000, lines: [{ ...draft?.lines[0], quantity: "-4", lineTotal: -40000 }] });
  const rows = (await send(owner, "GET", "/transactions")).body.transactions as Row[];
  const originalRow = rows.find((row) => row.id === original);
  const returRow = rows.find((row) => row.id === retur);
  assert.deepEqual([originalRow?.remaining, originalRow?.hasRetur, returRow?.remaining], [60000, true, 0]);
  const cashThatDay = await prisma.payment.aggregate({ where: { transaction: { storeId: owner.storeId }, date: new Date(`${today}T00:00:00Z`) }, _sum: { amount: true } });
  assert.equal(cashThatDay._sum.amount, 0);
});

test("returAgainstAPaidSaleGivesCashBack", async () => {
  const owner = await createOwner();
  const original = await saveEntry(owner, { businessDate: "2026-10-13", direction: "IN", total: 50000, lines: [line({ itemName: "Kaos", quantity: "1", unitPrice: 50000 })], payments: [paid("2026-10-13", 50000)] });
  const draft = ((await send(owner, "POST", `/transactions/${original}/retur`)).body.drafts as Draft[])[0];
  await saveEntry(owner, draft as unknown as Record<string, unknown>);
  const cashToday = await prisma.payment.aggregate({ where: { transaction: { storeId: owner.storeId }, date: new Date(`${today}T00:00:00Z`) }, _sum: { amount: true } });
  assert.equal(cashToday._sum.amount, -50000);
});

test("refusesAReturPointingTheOtherWayFromItsOriginal", async () => {
  const owner = await createOwner();
  const original = await saveEntry(owner, { businessDate: "2026-10-14", direction: "IN", total: 5000, lines: [line({ lineTotal: 5000 })], payments: [] });
  const reply = await post(owner, { businessDate: "2026-10-14", direction: "OUT", total: -5000, linkedTransactionId: original, lines: [line({ lineTotal: -5000 })], payments: [] });
  assert.equal(reply.status, 400);
});

test("pinjamanMasukOpensAnUtangToTheLenderThatBayarPaysOff", async () => {
  const owner = await createOwner();
  const loan = await saveEntry(owner, {
    businessDate: "2026-10-15",
    direction: "IN",
    total: 2000000,
    personName: "Koperasi",
    lines: [line({ categoryId: categoryId(owner, "IN:Pinjaman masuk"), lineTotal: 2000000 })],
    payments: [paid("2026-10-15", 2000000)],
  });
  const utang = (await send(owner, "GET", "/payables")).body.rows as Row[];
  const loanUtang = utang[0];
  assert.deepEqual([utang.length, loanUtang?.direction, loanUtang?.remaining, loanUtang?.person?.name, loanUtang?.lines[0]?.category?.name], [1, "OUT", 2000000, "Koperasi", "Bayar pinjaman"]);
  const link = await prisma.transaction.findUniqueOrThrow({ where: { id: loanUtang?.id ?? "" }, select: { linkedTransactionId: true } });
  assert.equal(link.linkedTransactionId, loan);
  await send(owner, "POST", `/transactions/${loanUtang?.id}/payments`, { amount: 500000 });
  assert.equal(((await send(owner, "GET", "/payables")).body.rows as Row[])[0]?.remaining, 1500000);
});

test("answersAnotherStoresEntryAsNotFoundEverywhere", async () => {
  const owner = await createOwner();
  const stranger = await createOwner();
  const id = await saveEntry(owner, { businessDate: "2026-10-16", direction: "IN", total: 1000, lines: [line({ lineTotal: 1000 })], payments: [] });
  const statuses = [
    (await send(stranger, "GET", `/transactions/${id}`)).status,
    (await send(stranger, "PATCH", `/transactions/${id}`, { direction: "IN", total: 1, lines: [] })).status,
    (await send(stranger, "GET", `/transactions/${id}/history`)).status,
    (await send(stranger, "POST", `/transactions/${id}/payments`, { amount: 1000 })).status,
    (await send(stranger, "POST", `/transactions/${id}/repeat`)).status,
    (await send(stranger, "POST", `/transactions/${id}/retur`)).status,
  ];
  const bayar = await send(owner, "POST", `/transactions/${id}/payments`, { amount: 500 });
  statuses.push((await send(stranger, "DELETE", `/payments/${(bayar.body.payment as { id: string }).id}`)).status);
  assert.deepEqual(statuses, [404, 404, 404, 404, 404, 404, 404]);
  assert.equal(await prisma.payment.count({ where: { transactionId: id } }), 1);
  assert.deepEqual(await listIds(stranger, ""), []);
});

// ---- Helpers ----------------------------------------------------------------

type Draft = { businessDate: string; total: number; personName: string | null; linkedTransactionId: string | null; payments: unknown[]; lines: { itemName: string | null; quantity: string | null; lineTotal: number | null }[] };

function line(fields: Partial<{ itemName: string; categoryId: string; quantity: string; unit: string; unitPrice: number; lineTotal: number }>): Record<string, unknown> {
  return { itemId: null, itemName: null, categoryId: null, quantity: null, unit: null, unitPrice: null, lineTotal: null, ...fields };
}

function paid(date: string, amount: number): { date: string; amount: number; label: string } {
  return { date, amount, label: "cash" };
}

async function saveEntry(owner: Owner, entry: Record<string, unknown> | undefined): Promise<string> {
  const reply = await post(owner, entry ?? {});
  assert.equal(reply.status, 201, JSON.stringify(reply.body));
  return (reply.body.transaction as Row).id;
}

async function post(owner: Owner, entry: Record<string, unknown>): Promise<Reply> {
  const response = await fetch(`${baseUrl}/transactions`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${owner.token}`, "Idempotency-Key": randomUUID() },
    body: JSON.stringify({ source: "TYPED", ...entry }),
  });
  return { status: response.status, body: (await response.json()) as Record<string, unknown> };
}

async function send(owner: Owner, method: string, path: string, body?: unknown): Promise<Reply> {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${owner.token}` },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: (await response.json()) as Record<string, unknown> };
}

async function listIds(owner: Owner, query: string): Promise<string[]> {
  const reply = await send(owner, "GET", `/transactions${query}`);
  return (reply.body.transactions as Row[]).map((row) => row.id);
}

async function createOwner(): Promise<Owner> {
  const name = "S6 Warung";
  const user = await prisma.user.create({
    data: {
      // 0899 is not a real Indonesian prefix, so a test owner can never take a real number.
      phone: `+62899${randomInt(10_000_000, 100_000_000)}`,
      passwordHash: "not-a-password",
      name,
      consentAt: new Date(),
      stores: { create: { name, businessTypes: ["JUALAN_BARANG"], closedDays: [], categories: { create: fixedCategoryRows() } } },
    },
    select: { id: true, stores: { select: { id: true, categories: { select: { id: true, name: true, direction: true } } } } },
  });
  const store = user.stores[0];
  if (store === undefined) {
    throw new Error("the test owner was created without a store");
  }
  const token = signToken({ userId: user.id, storeId: store.id }, { secret: config.jwtSecret, nowSeconds: Math.floor(Date.now() / 1000) });
  const owner = { userId: user.id, storeId: store.id, token, categoryIdByKey: new Map(store.categories.map((category) => [`${category.direction}:${category.name}`, category.id])) };
  owners.push(owner);
  return owner;
}

function categoryId(owner: Owner, key: string): string {
  const id = owner.categoryIdByKey.get(key);
  if (id === undefined) {
    throw new Error(`no category ${key}`);
  }
  return id;
}
