import { test } from "node:test";
import assert from "node:assert/strict";
import { computeLineMoney, isOverpaid, isPriceImplausible, mixesLumpSumAndItemised, planRetur, settleTotalGap } from "../../src/services/saveRules.js";

test("savesSpokenTotalAndRecordsDiscount", () => {
  // "nasi 2, 25 ribu aja" with nasi at Rp 15.000 (spec §7.3).
  assert.deepEqual(computeLineMoney({ quantity: "2", unitPrice: 15000, lineTotal: 25000 }, null), { unitPrice: 15000, lineTotal: 25000, discount: 5000, hasNoPrice: false });
});

test("computesQuantityTimesUnitPriceWhenNoTotalWasSaid", () => {
  assert.equal(computeLineMoney({ quantity: "0.5", unitPrice: 14000, lineTotal: null }, null).lineTotal, 7000);
});

test("roundsAFractionalQuantityToTheNearestRupiah", () => {
  assert.equal(computeLineMoney({ quantity: "0.123", unitPrice: 14005, lineTotal: null }, null).lineTotal, 1723);
});

test("fillsThePriceFromTheSavedItem", () => {
  assert.deepEqual(computeLineMoney({ quantity: "3", unitPrice: null, lineTotal: null }, 5000), { unitPrice: 5000, lineTotal: 15000, discount: 0, hasNoPrice: false });
});

test("keepsABareAmountWithNoDiscount", () => {
  assert.deepEqual(computeLineMoney({ quantity: null, unitPrice: null, lineTotal: 1200000 }, null), { unitPrice: null, lineTotal: 1200000, discount: 0, hasNoPrice: false });
});

test("savesALineWithNoPriceAtZeroAndFlagsIt", () => {
  assert.deepEqual(computeLineMoney({ quantity: "2", unitPrice: null, lineTotal: null }, null), { unitPrice: null, lineTotal: 0, discount: 0, hasNoPrice: true });
});

test("negativeReturQuantityGivesANegativeLineTotal", () => {
  assert.equal(computeLineMoney({ quantity: "-2", unitPrice: 30000, lineTotal: null }, null).lineTotal, -60000);
});

test("leavesLinesAloneWhenTheyAddUpToTheTotal", () => {
  const lines = [{ lineTotal: 10000, discount: 0 }];
  assert.deepEqual(settleTotalGap(lines, 10000), { lines, extraLineTotal: null });
});

test("takesAPrintedTotalBelowTheLinesAsDiscountFromTheLastLinesFirst", () => {
  const settled = settleTotalGap([{ lineTotal: 30000, discount: 0 }, { lineTotal: 5000, discount: 0 }], 28000);
  assert.deepEqual(settled, { lines: [{ lineTotal: 28000, discount: 2000 }, { lineTotal: 0, discount: 5000 }], extraLineTotal: null });
});

test("turnsATotalAboveTheLinesIntoAnExtraLine", () => {
  assert.equal(settleTotalGap([{ lineTotal: 30000, discount: 0 }], 48000).extraLineTotal, 18000);
});

test("neverTakesAReturLineFurtherBelowZero", () => {
  const settled = settleTotalGap([{ lineTotal: 10000, discount: 0 }, { lineTotal: -5000, discount: 0 }], -8000);
  assert.deepEqual(settled, { lines: [{ lineTotal: 0, discount: 10000 }, { lineTotal: -5000, discount: 0 }], extraLineTotal: -3000 });
});

test("flagsAPriceTenTimesAboveOrBelowTheSavedOne", () => {
  assert.deepEqual(
    [isPriceImplausible(150000, 15000), isPriceImplausible(1500, 15000), isPriceImplausible(149999, 15000), isPriceImplausible(1501, 15000), isPriceImplausible(150000, null)],
    [true, true, false, false, false],
  );
});

test("flagsPaymentsAboveTheTotalAsOverpaid", () => {
  assert.deepEqual([isOverpaid(100000, [{ amount: 60000 }, { amount: 60000 }]), isOverpaid(100000, [{ amount: 100000 }])], [true, false]);
});

test("warnsWhenALumpSumMeetsAnItemisedSaleOnTheSameDay", () => {
  assert.deepEqual(
    [
      mixesLumpSumAndItemised({ isItemised: false, sameDaySales: [{ isItemised: true }] }),
      mixesLumpSumAndItemised({ isItemised: true, sameDaySales: [{ isItemised: true }] }),
      mixesLumpSumAndItemised({ isItemised: true, sameDaySales: [] }),
    ],
    [true, false, false],
  );
});

test("returCancelsTheOpenBalanceFirstAndGivesTheRestBackInCash", () => {
  assert.deepEqual(
    [planRetur({ refund: 40000, openOnOriginal: 100000 }), planRetur({ refund: 40000, openOnOriginal: 10000 }), planRetur({ refund: 40000, openOnOriginal: -5000 })],
    [{ settledAgainstOriginal: 40000, cashBack: 0 }, { settledAgainstOriginal: 10000, cashBack: 30000 }, { settledAgainstOriginal: 0, cashBack: 40000 }],
  );
});
