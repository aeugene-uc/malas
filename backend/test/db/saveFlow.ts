import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import { prisma } from "../../src/db.js";
import { addDays } from "../../src/services/analytics.js";
import { getAlerts, getHome, getRankedRows, getSummary } from "../../src/services/analyticsService.js";
import { resolveBusinessDate } from "../../src/services/businessDate.js";
import { fixedCategoryRows } from "../../src/services/categories.js";
import { StoreQueries } from "../../src/services/tanyaQueries.js";
import * as transactionService from "../../src/services/transactionService.js";
import type { SaveRequest } from "../../src/services/transactionService.js";

// S11 part 2: what Simpan (S5) and Catatan (S6) save, read back the way
// Beranda, Analisis, Piutang/Utang and the alerts show it. savePath.ts and
// catatan.ts test the routes themselves; this tests that §10's figures follow
// from real saves, edits and returs. Needs a database, so it runs with
// `npm run test:db`. Its owners are deleted afterwards.

type Owner = { userId: string; storeId: string; bahanId: string };

let owner: Owner;
// Owners made by single tests, for cases that would change the day above.
const extraOwners: Owner[] = [];
let today = "";
const quickAmountKey = randomUUID();
let bonId = "";

before(async () => {
  owner = await createOwner("S11 Simpan");
  today = resolveBusinessDate({ now: new Date(), timezone: "Asia/Jakarta", dayChangeHour: 4 });
  await saveTheDay();
});

after(async () => {
  const userIds = [owner, ...extraOwners].filter((seeded) => seeded !== undefined).map((seeded) => seeded.userId);
  await prisma.user.deleteMany({ where: { id: { in: userIds } } });
  await prisma.$disconnect();
});

test("countsTodaysPaymentsOnBerandaWithTheSpokenTotalAndNotTheBon", async () => {
  const home = await getHome(owner.storeId);
  // Ketik's 1.200.000 + "nasi goreng 2, 25 ribu aja" at 25.000, not 30.000.
  // Pak Budi's bon is unpaid, and only the 100.000 paid to Toko A is Keluar.
  assert.deepEqual(home.today, { date: today, masuk: 1_225_000, keluar: 100_000 });
  assert.equal(home.entries.length, 4);
  const nasi = home.entries.flatMap((entry) => entry.lines).find((line) => line.item?.name === "Nasi goreng");
  assert.deepEqual([nasi?.lineTotal, nasi?.discount], [25_000, 5_000]);
});

test("ranksTheDiscountedLineAtWhatWasPaid", async () => {
  const sales = await getRankedRows(owner.storeId, { period: "minggu", start: today, direction: "IN", mode: "item" });
  assert.deepEqual(sales.map((row) => [row.name, row.amount]), [["Nasi goreng", 25_000]]);
});

test("showsTheBonAsPiutangAndTheTempoAndTheOverpaymentAsUtang", async () => {
  const queries = new StoreQueries(owner.storeId, []);
  assert.deepEqual(await queries.openBalances("PIUTANG"), { rows: [{ personName: "Pak Budi", remaining: 30_000 }], total: 30_000 });
  assert.deepEqual(await queries.openBalances("UTANG"), {
    rows: [
      { personName: "Toko A", remaining: 150_000 },
      { personName: "Bu Rina", remaining: 20_000 },
    ],
    total: 170_000,
  });
});

test("raisesTheDueDateAndThePriceRiseFromSavedEntries", async () => {
  const home = await getHome(owner.storeId);
  assert.deepEqual({ ...home.cards, alerts: home.cards.alerts.map((alert) => alert.message) }, {
    alerts: ["Utang ke Toko A Rp 150.000 jatuh tempo hari ini", "Harga Gula naik 10%: Rp 14.000 → Rp 15.400 per kg"],
    missedDays: [],
    piutang: 30_000,
    utang: 170_000,
    dueToday: 1,
    queuedReads: null,
  });
  assert.equal((await getAlerts(owner.storeId)).length, 2);
});

test("savesARetriedQuickAmountOnlyOnce", async () => {
  await transactionService.save({ storeId: owner.storeId, request: quickAmount(), idempotencyKey: quickAmountKey });
  const home = await getHome(owner.storeId);
  assert.equal(home.today.masuk, 1_225_000);
  assert.equal(home.entries.length, 4);
});

test("dropsTheBonFromPiutangOnBatalAndBringsItBackOnRestore", async () => {
  await transactionService.deleteTransaction(owner.storeId, bonId);
  assert.equal((await getHome(owner.storeId)).cards.piutang, null);
  await transactionService.restoreTransaction(owner.storeId, bonId);
  assert.equal((await getHome(owner.storeId)).cards.piutang, 30_000);
});

test("givesAnalisisAndTanyaTheSameTotalsForSavedEntries", async () => {
  const summary = await getSummary(owner.storeId, "minggu", today);
  const monday = addDays(today, -((new Date(`${today}T00:00:00Z`).getUTCDay() + 6) % 7));
  const totals = await new StoreQueries(owner.storeId, []).totals({ kind: "minggu", offset: 0, from: monday, to: today });
  assert.deepEqual([summary.masuk, summary.keluar], [totals.masuk, totals.keluar]);
});

test("showsAnEditBelowWhatWasPaidAsKembalikanOnBeranda", async () => {
  const shop = await createExtraOwner("S11 Edit");
  const bon = await saveEntry(shop, request({ direction: "IN", total: 100_000, personName: "Bu Ani", lines: [{ lineTotal: 100_000 }], payments: [] }));
  await transactionService.pay({ storeId: shop.storeId, transactionId: bon, amount: 80_000, date: null, label: null });
  // The owner finds the bon was only 60.000: Bu Ani is owed 20.000 back.
  await transactionService.edit({
    storeId: shop.storeId,
    transactionId: bon,
    request: request({ direction: "IN", total: 60_000, personName: "Bu Ani", lines: [{ lineTotal: 60_000 }], payments: [] }),
  });
  const home = await getHome(shop.storeId);
  assert.deepEqual([home.today.masuk, home.cards.piutang, home.cards.utang], [80_000, null, 20_000]);
  assert.deepEqual(await new StoreQueries(shop.storeId, []).openBalances("UTANG"), { rows: [{ personName: "Bu Ani", remaining: 20_000 }], total: 20_000 });
});

test("lowersPiutangForAReturOnABonWithoutTouchingMasuk", async () => {
  const shop = await createExtraOwner("S11 Retur bon");
  const bon = await saveEntry(
    shop,
    request({ direction: "IN", total: 100_000, personName: "Pak Budi", lines: [{ itemName: "Beras", quantity: "10", unit: "kg", unitPrice: 10_000, lineTotal: 100_000 }], payments: [] }),
  );
  // Pak Budi brings back 4 kg of the 10.
  await saveEntry(shop, {
    ...request({ direction: "IN", total: -40_000, lines: [{ itemName: "Beras", quantity: "-4", unit: "kg", unitPrice: 10_000, lineTotal: -40_000 }], payments: [] }),
    linkedTransactionId: bon,
  });
  const home = await getHome(shop.storeId);
  assert.deepEqual([home.today.masuk, home.cards.piutang], [0, 60_000]);
  const sales = await getRankedRows(shop.storeId, { period: "minggu", start: today, direction: "IN", mode: "item" });
  assert.deepEqual(sales.map((row) => [row.name, row.amount]), [["Beras", 60_000]]);
});

test("takesACashReturOffThatDaysMasukAndTheItemsSales", async () => {
  const shop = await createExtraOwner("S11 Retur tunai");
  const sale = await saveEntry(
    shop,
    request({ direction: "IN", total: 100_000, lines: [{ itemName: "Kaos", quantity: "2", unit: "pcs", unitPrice: 50_000, lineTotal: 100_000 }], payments: [{ date: today, amount: 100_000, label: "cash" }] }),
  );
  await saveEntry(shop, {
    ...request({ direction: "IN", total: -50_000, lines: [{ itemName: "Kaos", quantity: "-1", unit: "pcs", unitPrice: 50_000, lineTotal: -50_000 }], payments: [] }),
    linkedTransactionId: sale,
  });
  const home = await getHome(shop.storeId);
  assert.equal(home.today.masuk, 50_000);
  assert.equal(home.entries.find((entry) => entry.id === sale)?.hasRetur, true);
  const summary = await getSummary(shop.storeId, "minggu", today);
  const sales = await getRankedRows(shop.storeId, { period: "minggu", start: today, direction: "IN", mode: "item" });
  assert.equal(summary.masuk, 50_000);
  assert.deepEqual(sales.map((row) => [row.name, row.amount]), [["Kaos", 50_000]]);
});

// ---- Seed, through Simpan ----------------------------------------------------

async function saveTheDay(): Promise<void> {
  const saves: SaveRequest[] = [
    quickAmount(),
    request({
      direction: "IN",
      total: 25_000,
      lines: [{ itemName: "Nasi goreng", quantity: "2", unit: "porsi", unitPrice: 15_000, lineTotal: 25_000 }],
      payments: [{ date: today, amount: 25_000, label: "cash" }],
    }),
    request({ direction: "IN", total: 30_000, personName: "Pak Budi", lines: [{ lineTotal: 30_000 }], payments: [] }),
    request({
      direction: "OUT",
      total: 250_000,
      personName: "Toko A",
      dueDate: today,
      lines: [{ categoryId: owner.bahanId, lineTotal: 250_000 }],
      payments: [{ date: today, amount: 100_000, label: "cash" }],
    }),
    // Paid 660.000 on a 640.000 order: 20.000 is owed back (Kembalikan).
    request({
      businessDate: addDays(today, -1),
      direction: "IN",
      total: 640_000,
      personName: "Bu Rina",
      lines: [{ lineTotal: 640_000 }],
      payments: [{ date: addDays(today, -1), amount: 660_000, label: "cash" }],
    }),
    // Gula from 14.000 to 15.400 a kg: a 10% rise.
    ...[
      { daysAgo: 3, quantity: "1", lineTotal: 14_000 },
      { daysAgo: 1, quantity: "2", lineTotal: 30_800 },
    ].map((bought) =>
      request({
        businessDate: addDays(today, -bought.daysAgo),
        direction: "OUT",
        total: bought.lineTotal,
        lines: [{ itemName: "Gula", categoryId: owner.bahanId, quantity: bought.quantity, unit: "kg", lineTotal: bought.lineTotal }],
        payments: [{ date: addDays(today, -bought.daysAgo), amount: bought.lineTotal, label: "cash" }],
      }),
    ),
  ];
  for (const [index, saveRequest] of saves.entries()) {
    const saved = await transactionService.save({
      storeId: owner.storeId,
      request: saveRequest,
      idempotencyKey: index === 0 ? quickAmountKey : randomUUID(),
    });
    if (saveRequest.personName === "Pak Budi") {
      bonId = saved.transaction.id;
    }
  }
}

async function createExtraOwner(name: string): Promise<Owner> {
  const extra = await createOwner(name);
  extraOwners.push(extra);
  return extra;
}

async function saveEntry(shop: Owner, saveRequest: SaveRequest): Promise<string> {
  const saved = await transactionService.save({ storeId: shop.storeId, request: saveRequest, idempotencyKey: randomUUID() });
  return saved.transaction.id;
}

// Ketik's quick amount (§8.3): one bare line, paid in full, no date sent.
function quickAmount(): SaveRequest {
  return request({ direction: "IN", total: 1_200_000, lines: [{ lineTotal: 1_200_000 }], payments: [{ date: today, amount: 1_200_000, label: "cash" }] });
}

type LineSeed = { itemName?: string; categoryId?: string; quantity?: string; unit?: string; unitPrice?: number; lineTotal: number };

function request(options: {
  businessDate?: string;
  direction: "IN" | "OUT";
  total: number;
  personName?: string;
  dueDate?: string;
  lines: LineSeed[];
  payments: SaveRequest["payments"];
}): SaveRequest {
  return {
    businessDate: options.businessDate ?? null,
    direction: options.direction,
    total: options.total,
    personId: null,
    personName: options.personName ?? null,
    dueDate: options.dueDate ?? null,
    source: "TYPED",
    inputId: null,
    linkedTransactionId: null,
    note: null,
    lines: options.lines.map((line) => ({
      itemId: null,
      itemName: line.itemName ?? null,
      categoryId: line.categoryId ?? null,
      quantity: line.quantity ?? null,
      unit: line.unit ?? null,
      unitPrice: line.unitPrice ?? null,
      lineTotal: line.lineTotal,
    })),
    payments: options.payments,
  };
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
  const bahan = store?.categories.find((category) => category.name === "Bahan" && category.direction === "OUT");
  if (store === undefined || bahan === undefined) {
    throw new Error("the test owner was created without its store or fixed categories");
  }
  return { userId: user.id, storeId: store.id, bahanId: bahan.id };
}
