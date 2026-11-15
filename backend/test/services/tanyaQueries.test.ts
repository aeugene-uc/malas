import { test } from "node:test";
import assert from "node:assert/strict";
import { countDaysRecorded, isCountedInProfit, rankRows, sumOpenBalances } from "../../src/services/tanyaQueries.js";

test("leavesOutMoneyInCategoriesNotCountedInProfit", () => {
  assert.equal(isCountedInProfit([true, true]), true);
  assert.equal(isCountedInProfit([null]), true);
  assert.equal(isCountedInProfit([]), true);
  assert.equal(isCountedInProfit([false]), false);
  assert.equal(isCountedInProfit([false, true]), true);
});

test("countsEachRecordedDayOnceAndSkipsClosedDays", () => {
  const dates = ["2026-11-09", "2026-11-09", "2026-11-10", "2026-11-15"].map((date) => new Date(`${date}T00:00:00Z`));
  // 15 November 2026 is a Sunday, ISO weekday 7.
  assert.equal(countDaysRecorded(dates, []), 3);
  assert.equal(countDaysRecorded(dates, [7]), 2);
});

test("addsUpLinesPerNameAndRanksByAmount", () => {
  const rows = rankRows(
    [
      { label: "Es teh", amount: 15_000, quantity: "5", unit: null },
      { label: "Kopi susu", amount: 36_000, quantity: "2", unit: "porsi" },
      { label: "Es teh", amount: 9_000, quantity: "3", unit: null },
      { label: "Gula", amount: 8_000, quantity: "0.5", unit: "kg" },
      { label: "Gula", amount: 4_000, quantity: "0.25", unit: "kg" },
    ],
    2,
  );
  assert.deepEqual(rows, [
    { name: "Kopi susu", amount: 36_000, quantity: "2", unit: "porsi" },
    { name: "Es teh", amount: 24_000, quantity: "8", unit: null },
  ]);
  assert.equal(rankRows([{ label: "Gula", amount: 8_000, quantity: "0.5", unit: "kg" }, { label: "Gula", amount: 4_000, quantity: "0.25", unit: "kg" }], 3)[0]?.quantity, "0.75");
});

test("subtractsReturnedQuantities", () => {
  const [row] = rankRows([{ label: "Teh", amount: 30_000, quantity: "10", unit: null }, { label: "Teh", amount: -6_000, quantity: "-2", unit: null }], 3);
  assert.deepEqual([row?.amount, row?.quantity], [24_000, "8"]);
});

test("sumsPiutangPerPersonFromWhatIsStillUnpaid", () => {
  const balances = sumOpenBalances(
    [
      { direction: "IN", total: 30_000, paid: 0, personName: "Pak Budi" },
      { direction: "IN", total: 20_000, paid: 5_000, personName: "Pak Budi" },
      { direction: "IN", total: 50_000, paid: 50_000, personName: "Bu Ani" },
      { direction: "IN", total: 10_000, paid: 0, personName: null },
      { direction: "OUT", total: 99_000, paid: 0, personName: "Toko A" },
    ],
    "PIUTANG",
  );
  assert.deepEqual(balances, { rows: [{ personName: "Pak Budi", remaining: 45_000 }, { personName: null, remaining: 10_000 }], total: 55_000 });
});

test("countsUnpaidPurchasesAndOverpaymentsOwedBackAsUtang", () => {
  const balances = sumOpenBalances(
    [
      { direction: "OUT", total: 250_000, paid: 100_000, personName: "Toko Sumber Rejeki" },
      { direction: "IN", total: 640_000, paid: 660_000, personName: "Bu Rina" },
      { direction: "IN", total: 30_000, paid: 0, personName: "Pak Budi" },
    ],
    "UTANG",
  );
  assert.deepEqual(balances, { rows: [{ personName: "Toko Sumber Rejeki", remaining: 150_000 }, { personName: "Bu Rina", remaining: 20_000 }], total: 170_000 });
});
