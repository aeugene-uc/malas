import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { randomInt } from "node:crypto";
import { prisma } from "../../src/db.js";
import { addDays } from "../../src/services/analytics.js";
import { getHome, getRankedRows, getSummary } from "../../src/services/analyticsService.js";
import { resolveBusinessDate } from "../../src/services/businessDate.js";
import { fixedCategoryRows } from "../../src/services/categories.js";
import { normaliseName } from "../../src/services/normaliseName.js";
import { StoreQueries } from "../../src/services/tanyaQueries.js";

// Spec §10 on real rows (S11): which date each figure counts on, what is left
// out, and that Analisis, Beranda and Tanya give the same numbers. The rules
// that pick dates live in the queries, so these need a database: run them with
// `npm run test:db` against malas_dev. The file is not named *.test.ts, so
// `npm test` stays offline. Each run seeds its own two owners and deletes them
// afterwards; nothing else in the database is touched.

// Sundays closed. October 2026 has four Sundays: 4, 11, 18 and 25.
const SUNDAY = 7;
const OCTOBER = { kind: "bulan", offset: 0, from: "2026-10-01", to: "2026-10-31" } as const;

type Direction = "IN" | "OUT";
type Owner = { userId: string; storeId: string; categoryIdByKey: Map<string, string> };
type LineSeed = { category: string; itemId?: string; quantity?: string; lineTotal: number };
type EntrySeed = {
  businessDate: string;
  direction: Direction;
  total: number;
  lines: LineSeed[];
  payments: { date: string; amount: number }[];
  personId?: string;
  dueDate?: string;
  isDeleted?: boolean;
  isEdited?: boolean;
};

let owner: Owner;
let otherOwner: Owner;
let today = "";

before(async () => {
  owner = await createOwner("S11 Warung");
  otherOwner = await createOwner("S11 Tetangga");
  today = resolveBusinessDate({ now: new Date(), timezone: "Asia/Jakarta", dayChangeHour: 4 });
  await seedEntries();
});

after(async () => {
  await prisma.user.deleteMany({ where: { id: { in: [owner?.userId, otherOwner?.userId].filter((id): id is string => id !== undefined) } } });
  await prisma.$disconnect();
});

test("countsMasukAndKeluarOnPaymentDatesAndLeavesOutCreditDeletedEntriesAndOtherStores", async () => {
  const summary = await getSummary(owner.storeId, "bulan", OCTOBER.from);
  // Es teh 150.000 + the order's DP 300.000 + the Sunday sale 20.000. Pak Budi's
  // bon, the rest of the order (paid in November), the deleted sale, the Modal
  // and the other store's sale are not Masuk.
  assert.equal(summary.masuk, 470_000);
  // Only the 100.000 paid to Toko A, not the 250.000 bought on tempo.
  assert.equal(summary.keluar, 100_000);
  assert.equal(summary.untung, 370_000);
});

test("showsModalAndAmbilPribadiOnTheirOwnLine", async () => {
  const summary = await getSummary(owner.storeId, "bulan", OCTOBER.from);
  assert.deepEqual(summary.notCountedInProfit, { modal: 1_000_000, ambilPribadi: -200_000, pinjaman: 0, titipan: 0 });
});

test("comparesWithTheWholeMonthBeforeAndGivesNullWhenItHadNothing", async () => {
  const summary = await getSummary(owner.storeId, "bulan", OCTOBER.from);
  // September: one sale of 100.000, nothing spent.
  assert.deepEqual(summary.change, { masuk: 3.7, keluar: null, untung: 2.7 });
});

test("countsRecordedDaysWithoutClosedDaysOrDeletedEntries", async () => {
  const summary = await getSummary(owner.storeId, "bulan", OCTOBER.from);
  // 1, 5, 10, 12, 15 and 20 October. The 11th is a closed Sunday, and the 6th
  // only has a deleted entry.
  assert.equal(summary.daysRecorded, 6);
  assert.equal(summary.daysInPeriod, 27);
});

test("givesPiutangAndUtangAsTheyStoodAtTheEndOfThePeriod", async () => {
  const summary = await getSummary(owner.storeId, "bulan", OCTOBER.from);
  // The order's 700.000 was still open on 31 October, plus Pak Budi's 30.000.
  assert.equal(summary.piutangAtEnd, 730_000);
  assert.equal(summary.utangAtEnd, 150_000);
  // The deleted entry's edit does not count.
  assert.equal(summary.editedEntryCount, 1);
});

test("countsAnOrdersItemsOnTheOrderDateAndItsMoneyOnEachPaymentDate", async () => {
  const octoberSales = await getRankedRows(owner.storeId, { period: "bulan", start: OCTOBER.from, direction: "IN", mode: "item" });
  assert.deepEqual(
    octoberSales.map((row) => [row.name, row.amount, row.share]),
    [
      ["Kue lapis", 1_000_000, 0.8696],
      ["Es teh", 150_000, 0.1304],
    ],
  );
  const novemberSales = await getRankedRows(owner.storeId, { period: "bulan", start: "2026-11-01", direction: "IN", mode: "item" });
  assert.equal(novemberSales.some((row) => row.name === "Kue lapis"), false);
  const queries = new StoreQueries(owner.storeId, [SUNDAY]);
  const finalPaymentDay = { kind: "hari", offset: 0, from: "2026-11-02", to: "2026-11-02" } as const;
  assert.equal((await queries.totals(finalPaymentDay)).masuk, 700_000);
  const finalPaymentDaySales = await queries.byItem({ range: finalPaymentDay, direction: "IN", name: null, limit: 5 });
  assert.deepEqual(finalPaymentDaySales.rows, []);
});

test("ranksSpendingByCategoryWithoutAmbilPribadi", async () => {
  const octoberSpending = await getRankedRows(owner.storeId, { period: "bulan", start: OCTOBER.from, direction: "OUT", mode: "category" });
  // The whole 250.000 bought counts on its date, paid or not.
  assert.deepEqual(octoberSpending.map((row) => [row.name, row.amount, row.share]), [["Bahan", 250_000, 1]]);
});

test("givesTanyaTheSameTotalsAsAnalisis", async () => {
  const queries = new StoreQueries(owner.storeId, [SUNDAY]);
  const summary = await getSummary(owner.storeId, "bulan", OCTOBER.from);
  const totals = await queries.totals(OCTOBER);
  assert.deepEqual([totals.masuk, totals.keluar, totals.daysRecorded], [summary.masuk, summary.keluar, summary.daysRecorded]);
});

test("listsWhatIsStillOpenTodayPerPerson", async () => {
  const queries = new StoreQueries(owner.storeId, [SUNDAY]);
  // The order is fully paid by now. Pak Budi has two open bons.
  assert.deepEqual(await queries.openBalances("PIUTANG"), { rows: [{ personName: "Pak Budi", remaining: 55_000 }], total: 55_000 });
  assert.deepEqual(await queries.openBalances("UTANG"), { rows: [{ personName: "Toko A", remaining: 150_000 }], total: 150_000 });
});

test("showsTodayOnBerandaFromTodaysPaymentsAndOnlyThisStoresEntries", async () => {
  const home = await getHome(owner.storeId);
  assert.deepEqual(home.today, { date: today, masuk: 45_000, keluar: 0 });
  assert.equal(home.comparisons[0]?.label, "Kemarin");
  assert.equal(home.comparisons[0]?.masuk, 60_000);
  assert.equal(home.comparisons[1]?.masuk, 0);
  assert.deepEqual(
    home.entries.map((entry) => [entry.total, entry.paid, entry.remaining, entry.lines[0]?.item?.name, entry.lines[0]?.quantity]),
    [[45_000, 45_000, 0, "Es teh", "9"]],
  );
});

test("showsBerandaCardsOnlyWhenTheyHaveSomething", async () => {
  const { cards } = await getHome(owner.storeId);
  // The store was made today, so no earlier day can be missed.
  assert.deepEqual(cards, { alerts: [], missedDays: [], piutang: 55_000, utang: 150_000, dueToday: 1, queuedReads: null });
});

// ---- Seed ------------------------------------------------------------------

async function seedEntries(): Promise<void> {
  const esTeh = await createItem(owner, "Es teh");
  const kueLapis = await createItem(owner, "Kue lapis");
  const pakBudi = await createPerson(owner, "Pak Budi");
  const tokoA = await createPerson(owner, "Toko A");
  const entries: EntrySeed[] = [
    { businessDate: "2026-09-30", direction: "IN", total: 100_000, lines: [{ category: "IN:Penjualan", lineTotal: 100_000 }], payments: [{ date: "2026-09-30", amount: 100_000 }] },
    { businessDate: "2026-10-01", direction: "IN", total: 1_000_000, lines: [{ category: "IN:Modal masuk", lineTotal: 1_000_000 }], payments: [{ date: "2026-10-01", amount: 1_000_000 }] },
    {
      businessDate: "2026-10-05",
      direction: "IN",
      total: 150_000,
      lines: [{ category: "IN:Penjualan", itemId: esTeh, quantity: "30", lineTotal: 150_000 }],
      payments: [{ date: "2026-10-05", amount: 150_000 }],
      isEdited: true,
    },
    {
      businessDate: "2026-10-06",
      direction: "IN",
      total: 500_000,
      lines: [{ category: "IN:Penjualan", itemId: esTeh, quantity: "100", lineTotal: 500_000 }],
      payments: [{ date: "2026-10-06", amount: 500_000 }],
      isDeleted: true,
      isEdited: true,
    },
    // An order with a DP: 300.000 on the order date, the rest in November.
    {
      businessDate: "2026-10-10",
      direction: "IN",
      total: 1_000_000,
      lines: [{ category: "IN:Penjualan", itemId: kueLapis, quantity: "10", lineTotal: 1_000_000 }],
      payments: [
        { date: "2026-10-10", amount: 300_000 },
        { date: "2026-11-02", amount: 700_000 },
      ],
    },
    { businessDate: "2026-10-11", direction: "IN", total: 20_000, lines: [{ category: "IN:Penjualan", lineTotal: 20_000 }], payments: [{ date: "2026-10-11", amount: 20_000 }] },
    { businessDate: "2026-10-12", direction: "IN", total: 30_000, lines: [{ category: "IN:Penjualan", lineTotal: 30_000 }], payments: [], personId: pakBudi },
    {
      businessDate: "2026-10-15",
      direction: "OUT",
      total: 250_000,
      lines: [{ category: "OUT:Bahan", lineTotal: 250_000 }],
      payments: [{ date: "2026-10-15", amount: 100_000 }],
      personId: tokoA,
      dueDate: "2026-11-15",
    },
    { businessDate: "2026-10-20", direction: "OUT", total: 200_000, lines: [{ category: "OUT:Ambil pribadi", lineTotal: 200_000 }], payments: [{ date: "2026-10-20", amount: 200_000 }] },
    // Around today, for Beranda.
    {
      businessDate: today,
      direction: "IN",
      total: 45_000,
      lines: [{ category: "IN:Penjualan", itemId: esTeh, quantity: "9", lineTotal: 45_000 }],
      payments: [{ date: today, amount: 45_000 }],
    },
    { businessDate: addDays(today, -1), direction: "IN", total: 60_000, lines: [{ category: "IN:Penjualan", lineTotal: 60_000 }], payments: [{ date: addDays(today, -1), amount: 60_000 }] },
    { businessDate: addDays(today, -3), direction: "IN", total: 25_000, lines: [{ category: "IN:Penjualan", lineTotal: 25_000 }], payments: [], personId: pakBudi, dueDate: today },
  ];
  for (const entry of entries) {
    await createEntry(owner, entry);
  }
  // A neighbour's sales on the same days must never show in this store's figures.
  for (const businessDate of [OCTOBER.from, "2026-10-05", today]) {
    await createEntry(otherOwner, {
      businessDate,
      direction: "IN",
      total: 999_000,
      lines: [{ category: "IN:Penjualan", lineTotal: 999_000 }],
      payments: [{ date: businessDate, amount: 999_000 }],
    });
  }
}

async function createOwner(name: string): Promise<Owner> {
  const user = await prisma.user.create({
    data: {
      // 0899 is not a real Indonesian prefix, so a test owner can never take a real number.
      phone: `+62899${randomInt(10_000_000, 100_000_000)}`,
      passwordHash: "not-a-password",
      name,
      consentAt: new Date(),
      stores: { create: { name, businessTypes: ["MAKANAN_MINUMAN"], closedDays: [SUNDAY], categories: { create: fixedCategoryRows() } } },
    },
    select: { id: true, stores: { select: { id: true, categories: { select: { id: true, name: true, direction: true } } } } },
  });
  const store = user.stores[0];
  if (store === undefined) {
    throw new Error("the test owner was created without a store");
  }
  const categoryIdByKey = new Map(store.categories.map((category) => [`${category.direction}:${category.name}`, category.id]));
  return { userId: user.id, storeId: store.id, categoryIdByKey };
}

async function createItem(itemOwner: Owner, name: string): Promise<string> {
  const item = await prisma.item.create({
    data: { storeId: itemOwner.storeId, name, normalisedName: normaliseName(name), kind: "SOLD", categoryId: categoryId(itemOwner, "IN:Penjualan") },
  });
  return item.id;
}

async function createPerson(personOwner: Owner, name: string): Promise<string> {
  const person = await prisma.person.create({ data: { storeId: personOwner.storeId, name } });
  return person.id;
}

async function createEntry(entryOwner: Owner, entry: EntrySeed): Promise<void> {
  const transaction = await prisma.transaction.create({
    data: {
      storeId: entryOwner.storeId,
      businessDate: toDate(entry.businessDate),
      direction: entry.direction,
      total: entry.total,
      source: "TYPED",
      personId: entry.personId ?? null,
      dueDate: entry.dueDate === undefined ? null : toDate(entry.dueDate),
      deletedAt: entry.isDeleted === true ? new Date() : null,
      lines: {
        create: entry.lines.map((line) => ({
          itemId: line.itemId ?? null,
          categoryId: categoryId(entryOwner, line.category),
          quantity: line.quantity ?? null,
          lineTotal: line.lineTotal,
        })),
      },
      payments: { create: entry.payments.map((payment) => ({ date: toDate(payment.date), amount: payment.amount, label: "cash" })) },
    },
  });
  if (entry.isEdited === true) {
    await prisma.editHistory.create({ data: { transactionId: transaction.id, previous: { total: entry.total } } });
  }
}

function categoryId(categoryOwner: Owner, key: string): string {
  const id = categoryOwner.categoryIdByKey.get(key);
  if (id === undefined) {
    throw new Error(`no fixed category ${key}`);
  }
  return id;
}

function toDate(date: string): Date {
  return new Date(`${date}T00:00:00Z`);
}
