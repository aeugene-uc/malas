import { test } from "node:test";
import assert from "node:assert/strict";
import { changeRatio, countOpenDays, missedDays, periodFromStart, previousPeriod, rankLines, weekdayName, type RankLine } from "../../src/services/analytics.js";
import { splitPayments } from "../../src/services/tanyaQueries.js";

// Sunday 15 November 2026.
const today = "2026-11-15";

test("turnsAPeriodStartIntoItsDatesEndingToday", () => {
  assert.deepEqual(periodFromStart("minggu", "2026-11-09", today), { from: "2026-11-09", to: "2026-11-15" });
  assert.deepEqual(periodFromStart("bulan", "2026-11-01", today), { from: "2026-11-01", to: "2026-11-15" });
  assert.deepEqual(periodFromStart("bulan", "2026-10-01", today), { from: "2026-10-01", to: "2026-10-31" });
  assert.deepEqual(periodFromStart("tahun", "2025-01-01", today), { from: "2025-01-01", to: "2025-12-31" });
  // A start that is not the first day still means its whole period.
  assert.deepEqual(periodFromStart("minggu", "2026-11-12", today), { from: "2026-11-09", to: "2026-11-15" });
});

test("comparesWithTheWholePeriodBefore", () => {
  assert.deepEqual(previousPeriod("minggu", "2026-11-09"), { from: "2026-11-02", to: "2026-11-08" });
  assert.deepEqual(previousPeriod("bulan", "2026-11-01"), { from: "2026-10-01", to: "2026-10-31" });
  assert.deepEqual(previousPeriod("bulan", "2026-01-01"), { from: "2025-12-01", to: "2025-12-31" });
  assert.deepEqual(previousPeriod("tahun", "2026-01-01"), { from: "2025-01-01", to: "2025-12-31" });
});

test("givesTheChangeAsAFractionAndNullWithoutAPreviousFigure", () => {
  assert.equal(changeRatio(112, 100), 0.12);
  assert.equal(changeRatio(95, 100), -0.05);
  assert.equal(changeRatio(500, 0), null);
  assert.equal(changeRatio(-50, -100), 0.5);
});

test("countsOpenDaysAndFindsMissedOnesSkippingClosedDays", () => {
  const week = { from: "2026-11-09", to: "2026-11-15" };
  assert.equal(countOpenDays(week, []), 7);
  assert.equal(countOpenDays(week, [7]), 6);
  assert.deepEqual(missedDays(week, new Set(["2026-11-09", "2026-11-11", "2026-11-12", "2026-11-13", "2026-11-14"]), [7]), ["2026-11-10"]);
});

test("ranksMoneyInByItemAndMoneyOutByCategoryAndExpenseItem", () => {
  const penjualan = { id: "cat-jual", name: "Penjualan" };
  const sewa = { id: "cat-sewa", name: "Sewa" };
  const lines: RankLine[] = [
    { lineTotal: 60_000, countedInProfit: true, item: { id: "item-nasi", name: "Nasi goreng" }, category: penjualan },
    { lineTotal: 20_000, countedInProfit: true, item: { id: "item-teh", name: "Es teh" }, category: penjualan },
    { lineTotal: 20_000, countedInProfit: true, item: null, category: penjualan },
    { lineTotal: 1_000_000, countedInProfit: false, item: null, category: { id: "cat-modal", name: "Modal masuk" } },
  ];
  assert.deepEqual(rankLines(lines, "item"), [
    { id: "item-nasi", name: "Nasi goreng", amount: 60_000, share: 0.75 },
    { id: "item-teh", name: "Es teh", amount: 20_000, share: 0.25 },
  ]);
  const spending: RankLine[] = [
    { lineTotal: 75_000, countedInProfit: true, item: { id: "item-gas", name: "Gas" }, category: { id: "cat-ops", name: "Operasional" } },
    { lineTotal: 1_000_000, countedInProfit: true, item: null, category: sewa },
    { lineTotal: 25_000, countedInProfit: null, item: null, category: null },
    // The owner taking money out is not spending: it has its own summary line.
    { lineTotal: 500_000, countedInProfit: false, item: null, category: { id: "cat-ambil", name: "Ambil pribadi" } },
  ];
  assert.deepEqual(rankLines(spending, "category").map((row) => [row.name, row.amount, row.share]), [
    ["Sewa", 1_000_000, 0.9091],
    ["Gas", 75_000, 0.0682],
    ["Tanpa kategori", 25_000, 0.0227],
  ]);
});

test("putsMoneyNotCountedInProfitInItsOwnGroupsNetOfMoneyBack", () => {
  const result = splitPayments([
    { amount: 115_000, direction: "IN", lines: [{ lineTotal: 115_000, categoryName: "Penjualan", countedInProfit: true }] },
    { amount: 50_000, direction: "OUT", lines: [{ lineTotal: 50_000, categoryName: "Operasional", countedInProfit: true }] },
    { amount: 1_000_000, direction: "IN", lines: [{ lineTotal: 1_000_000, categoryName: "Modal masuk", countedInProfit: false }] },
    { amount: 200_000, direction: "OUT", lines: [{ lineTotal: 200_000, categoryName: "Ambil pribadi", countedInProfit: false }] },
    { amount: 500_000, direction: "IN", lines: [{ lineTotal: 500_000, categoryName: "Pinjaman masuk", countedInProfit: false }] },
    { amount: 100_000, direction: "OUT", lines: [{ lineTotal: 100_000, categoryName: "Bayar pinjaman", countedInProfit: false }] },
  ]);
  assert.deepEqual(result, {
    masuk: 115_000,
    keluar: 50_000,
    notCountedInProfit: { modal: 1_000_000, ambilPribadi: -200_000, pinjaman: 400_000, titipan: 0 },
  });
});

test("namesTheWeekdayForTheSameDayLastWeek", () => {
  assert.equal(weekdayName("2026-11-10"), "Selasa");
  assert.equal(weekdayName("2026-11-15"), "Minggu");
});
