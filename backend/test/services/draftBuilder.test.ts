import { test } from "node:test";
import assert from "node:assert/strict";
import type { HeardLine } from "../../src/ai/readPrompt.js";
import { buildDrafts, type PrintedDocument } from "../../src/services/draftBuilder.js";

const today = "2026-11-12";

function heard(overrides: Partial<HeardLine>): HeardLine {
  return {
    direction: "IN",
    name: null,
    quantityText: null,
    unit: null,
    unitPriceText: null,
    amountText: null,
    paidText: null,
    person: null,
    dueInDays: null,
    category: null,
    paymentLabel: null,
    dateOffset: 0,
    confidence: 0.9,
    ...overrides,
  };
}

function build(heardLines: HeardLine[]) {
  return buildDrafts({ heardLines, source: "VOICE", inputId: "input-1", todayBusinessDate: today });
}

// Spec §7.2: this sentence becomes 4 lines, the last one a Piutang.
test("turnsTheSpecExampleIntoThreeTransactionsWithOneOpenPiutang", () => {
  const { drafts } = build([
    heard({ name: "nasi goreng", quantityText: "12" }),
    heard({ name: "es teh", quantityText: "selawe" }),
    heard({ direction: "OUT", name: "gas", amountText: "25 ribu" }),
    heard({ person: "Pak Budi", amountText: "30 ribu", paidText: "0" }),
  ]);

  assert.equal(drafts.length, 3);
  const [sale, purchase, bon] = drafts;
  assert.deepEqual(sale?.lines.map((line) => [line.itemName, line.quantity]), [["nasi goreng", "12"], ["es teh", "25"]]);
  assert.deepEqual([purchase?.direction, purchase?.total, purchase?.payments.map((p) => p.amount)], ["OUT", 25_000, [25_000]]);
  assert.deepEqual([bon?.personName, bon?.total, bon?.payments], ["Pak Budi", 30_000, []]);
});

test("readsSelaweAfterAnItemAsAQuantityEvenWhenTheModelCallsItAnAmount", () => {
  const { drafts } = build([heard({ name: "es teh", amountText: "selawe" })]);
  const line = drafts[0]?.lines[0];
  assert.equal(line?.quantity, "25");
  assert.equal(line?.lineTotal, null);
});

test("keepsAmountsWithRibuJutaSlangOrThousandsDotsAsMoney", () => {
  for (const [amountText, expected] of [["25 ribu", 25_000], ["ceban", 10_000], ["25.000", 25_000], ["500000", 500_000], ["1,2 juta", 1_200_000]] as const) {
    const line = build([heard({ name: "x", amountText })]).drafts[0]?.lines[0];
    assert.deepEqual([line?.lineTotal, line?.quantity], [expected, null], amountText);
  }
});

test("letsASpokenTotalWinOverQuantityTimesPrice", () => {
  const line = build([heard({ name: "nasi", quantityText: "2", amountText: "25 ribu" })]).drafts[0]?.lines[0];
  assert.deepEqual([line?.quantity, line?.lineTotal, line?.unitPrice], ["2", 25_000, null]);
});

test("computesLineTotalFromQuantityTimesUnitPrice", () => {
  const draft = build([
    heard({ name: "gula", quantityText: "setengah kilo", unitPriceText: "30 ribu" }),
    heard({ name: "kopi", quantityText: "2", unit: "porsi", unitPriceText: "15 ribu" }),
  ]).drafts[0];
  assert.deepEqual(draft?.lines.map((line) => [line.quantity, line.unit, line.lineTotal]), [["0.5", "kg", 15_000], ["2", "porsi", 30_000]]);
  assert.equal(draft?.total, 45_000);
});

test("leavesLineTotalNullWhenNoPriceWasSaid", () => {
  const draft = build([heard({ name: "kopi susu", quantityText: "3" })]).drafts[0];
  assert.deepEqual([draft?.lines[0]?.lineTotal, draft?.total, draft?.payments], [null, 0, []]);
});

test("recordsFullPaymentOnTheBusinessDateWhenNothingWasSaidAboutPaying", () => {
  const draft = build([heard({ name: "kopi", amountText: "20 ribu", paymentLabel: "qris" })]).drafts[0];
  assert.deepEqual(draft?.payments, [{ date: today, amount: 20_000, label: "qris" }]);
});

test("recordsAPartPaymentForADpAndLeavesTheRestOpen", () => {
  const draft = build([heard({ person: "Bu Ani", name: "kue pesanan", amountText: "2 juta", paidText: "500 ribu" })]).drafts[0];
  assert.deepEqual([draft?.total, draft?.payments.map((payment) => payment.amount)], [2_000_000, [500_000]]);
});

test("datesTheDraftYesterdayAndOmitsTheDateForToday", () => {
  const [todays, yesterdays] = build([
    heard({ name: "kopi", amountText: "10 ribu" }),
    heard({ name: "teh", amountText: "5 ribu", dateOffset: -1 }),
  ]).drafts;
  assert.equal(todays?.businessDate, undefined);
  assert.equal(yesterdays?.businessDate, "2026-11-11");
  assert.equal(yesterdays?.payments[0]?.date, "2026-11-11");
});

test("movesTheDateAcrossMonthsAndSetsTheDueDate", () => {
  const draft = build([heard({ person: "Pak Budi", amountText: "30 ribu", paidText: "0", dueInDays: 21, dateOffset: -12 })]).drafts[0];
  assert.deepEqual([draft?.businessDate, draft?.dueDate], ["2026-10-31", "2026-11-21"]);
});

test("flagsAnAmountItCouldNotReadInsteadOfGuessing", () => {
  const { drafts, warnings } = build([heard({ name: "kopi", amountText: "banyak banget" })]);
  assert.equal(drafts[0]?.lines[0]?.lineTotal, null);
  assert.deepEqual(warnings.map(({ code, draftIndex, lineIndex }) => [code, draftIndex, lineIndex]), [["UNCLEAR_READ", 0, 0]]);
});

test("flagsALowConfidenceLine", () => {
  const { warnings } = build([heard({ name: "kopi", amountText: "10 ribu", confidence: 0.4 })]);
  assert.deepEqual(warnings.map((warning) => warning.code), ["UNCLEAR_READ"]);
});

test("keepsMoneyInAndMoneyOutInSeparateTransactions", () => {
  const { drafts } = build([
    heard({ name: "kopi", amountText: "10 ribu" }),
    heard({ direction: "OUT", name: "gula", amountText: "20 ribu" }),
    heard({ name: "teh", amountText: "5 ribu" }),
  ]);
  assert.deepEqual(drafts.map((draft) => [draft.direction, draft.total]), [["IN", 15_000], ["OUT", 20_000]]);
});

const receiptDocument: PrintedDocument = { seller: "Toko Sumber Rejeki", date: "2026-11-10", totalText: "50000" };

function buildPrinted(heardLines: HeardLine[], document: PrintedDocument = receiptDocument, source: "PHOTO" | "NOTEBOOK" = "PHOTO") {
  return buildDrafts({ heardLines, source, inputId: "input-2", todayBusinessDate: today, document });
}

test("makesTheSellerThePersonAndTheDocumentDateTheBusinessDate", () => {
  const draft = buildPrinted([
    heard({ direction: "OUT", name: "gula", quantityText: "2", unit: "kg", unitPriceText: "15000", amountText: "30000" }),
  ]).drafts[0];
  assert.deepEqual([draft?.personName, draft?.businessDate, draft?.payments[0]?.date], ["Toko Sumber Rejeki", "2026-11-10", "2026-11-10"]);
});

test("letsThePrintedGrandTotalWinOverTheSumOfTheLines", () => {
  const draft = buildPrinted([
    heard({ direction: "OUT", name: "gula", amountText: "30000" }),
    heard({ direction: "OUT", name: "minyak", amountText: "18000" }),
  ]).drafts[0];
  assert.deepEqual([draft?.total, draft?.payments.map((payment) => payment.amount)], [50_000, [50_000]]);
});

test("ignoresThePrintedTotalWhenThePageBecameSeveralTransactions", () => {
  const { drafts } = buildPrinted(
    [heard({ name: "kopi", amountText: "10 ribu" }), heard({ direction: "OUT", name: "gula", amountText: "20 ribu" })],
    { seller: null, date: null, totalText: "99999" },
    "NOTEBOOK",
  );
  assert.deepEqual(drafts.map((draft) => draft.total), [10_000, 20_000]);
});

test("flagsAPrintedLineWhereQuantityTimesPriceIsNotTheLineTotal", () => {
  const { drafts, warnings } = buildPrinted([
    heard({ direction: "OUT", name: "gula", quantityText: "2", unitPriceText: "15000", amountText: "31000" }),
  ]);
  assert.equal(drafts[0]?.lines[0]?.lineTotal, 31_000);
  assert.deepEqual(warnings.map((warning) => warning.code), ["UNCLEAR_READ"]);
});

test("doesNotFlagASpokenTotalThatDiffersFromQuantityTimesPrice", () => {
  const { warnings } = build([heard({ name: "kopi", quantityText: "3", unitPriceText: "15 ribu", amountText: "40 ribu" })]);
  assert.deepEqual(warnings, []);
});

test("keepsABareSmallAmountOnAPrintedPageButFlagsIt", () => {
  const { drafts, warnings } = buildPrinted([heard({ name: "kopi", amountText: "15" })], { seller: null, date: null, totalText: null }, "NOTEBOOK");
  assert.deepEqual([drafts[0]?.lines[0]?.lineTotal, drafts[0]?.lines[0]?.quantity], [15, null]);
  assert.deepEqual(warnings.map((warning) => warning.code), ["UNCLEAR_READ"]);
});

test("ignoresAndFlagsADocumentDateInTheFutureOrNotARealDay", () => {
  for (const date of ["2026-12-01", "2026-02-30", "2026-13-01", "12/11/2026"]) {
    const { drafts, warnings } = buildPrinted([heard({ name: "kopi", amountText: "10 ribu" })], { seller: null, date, totalText: null });
    assert.deepEqual([drafts[0]?.businessDate, warnings.length], [undefined, 1], date);
  }
});

test("flagsAPrintedTotalItCouldNotReadAndKeepsTheSumOfTheLines", () => {
  const { drafts, warnings } = buildPrinted([heard({ direction: "OUT", name: "gula", amountText: "30000" })], { seller: null, date: null, totalText: "lunas" });
  assert.deepEqual([drafts[0]?.total, warnings.length], [30_000, 1]);
});
