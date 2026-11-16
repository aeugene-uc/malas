import { test } from "node:test";
import assert from "node:assert/strict";
import { findDueToday, findPriceRises, formatRupiah, pickAlertsToRaise, type AlertCandidate, type PurchaseLine } from "../../src/services/alertRules.js";

// Monday 16 November 2026.
const today = "2026-11-16";

function purchase(overrides: Partial<PurchaseLine> & Pick<PurchaseLine, "businessDate" | "quantity" | "lineTotal">): PurchaseLine {
  return { transactionId: `tx-${overrides.businessDate}`, createdAt: new Date(`${overrides.businessDate}T03:00:00Z`), itemId: "item-gula", itemName: "Gula", unit: "kg", ...overrides };
}

function candidate(overrides: Partial<AlertCandidate> & Pick<AlertCandidate, "entryId" | "size">): AlertCandidate {
  return { rule: "DUE_TODAY", itemId: null, message: "", ...overrides };
}

test("raisesAPriceRiseFromTheSecondPurchaseAtTenPercentOrMore", () => {
  const rises = findPriceRises(
    [purchase({ businessDate: "2026-11-10", quantity: "1", lineTotal: 14_000 }), purchase({ businessDate: "2026-11-14", quantity: "2", lineTotal: 30_800 })],
    today,
  );
  assert.deepEqual(rises, [
    { rule: "PRICE_RISE", itemId: "item-gula", entryId: "tx-2026-11-14", message: "Harga Gula naik 10%: Rp 14.000 → Rp 15.400 per kg", size: 2_800 },
  ]);
  assert.deepEqual(findPriceRises([purchase({ businessDate: "2026-11-14", quantity: "2", lineTotal: 30_800 })], today), []);
});

test("staysQuietBelowTenPercentAndComparesOnlyWithinTheSameUnit", () => {
  const justUnder = [purchase({ businessDate: "2026-11-10", quantity: "1", lineTotal: 14_000 }), purchase({ businessDate: "2026-11-14", quantity: "1", lineTotal: 15_399 })];
  assert.deepEqual(findPriceRises(justUnder, today), []);
  // A sack in kg and a small pack in pcs are different prices, not a rise.
  const otherUnit = [purchase({ businessDate: "2026-11-10", quantity: "50", unit: "kg", lineTotal: 700_000 }), purchase({ businessDate: "2026-11-14", quantity: "4", unit: "pcs", lineTotal: 72_000 })];
  assert.deepEqual(findPriceRises(otherUnit, today), []);
});

test("comparesTheLatestPurchaseWithTheOneBeforeItInOrderBought", () => {
  // Out of order, and two on one day: the rise is from 16.000 to 18.000.
  const rises = findPriceRises(
    [
      purchase({ businessDate: "2026-11-14", createdAt: new Date("2026-11-14T09:00:00Z"), transactionId: "tx-late", quantity: "1", lineTotal: 18_000 }),
      purchase({ businessDate: "2026-11-01", quantity: "1", lineTotal: 12_000 }),
      purchase({ businessDate: "2026-11-14", createdAt: new Date("2026-11-14T02:00:00Z"), transactionId: "tx-early", quantity: "1", lineTotal: 16_000 }),
    ],
    today,
  );
  assert.deepEqual(rises.map((rise) => [rise.entryId, rise.message]), [["tx-late", "Harga Gula naik 13%: Rp 16.000 → Rp 18.000 per kg"]]);
});

test("ignoresARiseRecordedMoreThanAWeekAgoAndReturnedGoods", () => {
  const oldRise = [purchase({ businessDate: "2026-10-01", quantity: "1", lineTotal: 10_000 }), purchase({ businessDate: "2026-11-09", quantity: "1", lineTotal: 20_000 })];
  assert.deepEqual(findPriceRises(oldRise, today), []);
  const retur = [purchase({ businessDate: "2026-11-10", quantity: "2", lineTotal: 28_000 }), purchase({ businessDate: "2026-11-14", quantity: "-1", lineTotal: -20_000 })];
  assert.deepEqual(findPriceRises(retur, today), []);
});

test("raisesDueTodayForWhatIsStillOpenWithThePersonsName", () => {
  const alerts = findDueToday([
    { transactionId: "tx-budi", direction: "IN", remaining: 30_000, personName: "Pak Budi" },
    { transactionId: "tx-toko", direction: "OUT", remaining: 1_250_000, personName: "Toko A" },
    { transactionId: "tx-anon", direction: "IN", remaining: 5_000, personName: null },
    { transactionId: "tx-paid", direction: "IN", remaining: 0, personName: "Bu Ani" },
  ]);
  assert.deepEqual(
    alerts.map((alert) => [alert.entryId, alert.message, alert.size]),
    [
      ["tx-budi", "Piutang Pak Budi Rp 30.000 jatuh tempo hari ini", 30_000],
      ["tx-toko", "Utang ke Toko A Rp 1.250.000 jatuh tempo hari ini", 1_250_000],
      ["tx-anon", "Piutang Rp 5.000 jatuh tempo hari ini", 5_000],
    ],
  );
});

test("raisesAtMostThreeADayLargestFirstCountingOnesAlreadyRaisedToday", () => {
  const candidates = [10, 50, 20, 40, 30].map((size) => candidate({ entryId: `tx-${size}`, size }));
  const picked = pickAlertsToRaise({ candidates, recentAlerts: [], mutedItemIds: new Set(), today });
  assert.deepEqual(picked.map((alert) => alert.size), [50, 40, 30]);
  const raisedThisMorning = [{ rule: "DUE_TODAY", itemId: null, entryId: "tx-old", businessDate: today }];
  assert.deepEqual(pickAlertsToRaise({ candidates, recentAlerts: raisedThisMorning, mutedItemIds: new Set(), today }).map((alert) => alert.size), [50, 40]);
});

test("skipsAMutedItemAndAnAlertRaisedInTheLastSevenDays", () => {
  const gula = candidate({ rule: "PRICE_RISE", itemId: "item-gula", entryId: "tx-new-gula", size: 9_000 });
  const minyak = candidate({ rule: "PRICE_RISE", itemId: "item-minyak", entryId: "tx-minyak", size: 8_000 });
  const telur = candidate({ rule: "PRICE_RISE", itemId: "item-telur", entryId: "tx-telur", size: 7_000 });
  const picked = pickAlertsToRaise({
    candidates: [gula, minyak, telur],
    // Gula rose 6 days ago (inside the window), telur 7 days ago (outside it).
    recentAlerts: [
      { rule: "PRICE_RISE", itemId: "item-gula", entryId: "tx-old-gula", businessDate: "2026-11-10" },
      { rule: "PRICE_RISE", itemId: "item-telur", entryId: "tx-old-telur", businessDate: "2026-11-09" },
    ],
    mutedItemIds: new Set(["item-minyak"]),
    today,
  });
  assert.deepEqual(picked.map((alert) => alert.itemId), ["item-telur"]);
});

test("formatsRupiahWithDotsBetweenThousands", () => {
  assert.equal(formatRupiah(500), "Rp 500");
  assert.equal(formatRupiah(12_500), "Rp 12.500");
  assert.equal(formatRupiah(1_250_000), "Rp 1.250.000");
});
