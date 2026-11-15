import { afterEach, mock, test } from "node:test";
import assert from "node:assert/strict";
import type { AskIntent } from "../../src/ai/askPrompt.js";

// config reads the environment at import, so it is set before the import.
process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test";
process.env.GEMMA_API_KEY = "test-key";
const { answerIntent, askTanya, resolvePeriod } = await import("../../src/services/tanya.js");
type TanyaQueries = import("../../src/services/tanya.js").TanyaQueries;
type RankOptions = import("../../src/services/tanya.js").RankOptions;

// Sunday 15 November 2026.
const today = "2026-11-15";

function intent(overrides: Partial<AskIntent>): AskIntent {
  return { function: "totals", period: "bulan", periodOffset: 0, comparePeriodOffset: null, direction: null, name: null, balance: null, ...overrides };
}

// Fake queries that return fixed figures and record what they were asked.
function fakeQueries(): TanyaQueries & { rankCalls: RankOptions[] } {
  const rankCalls: RankOptions[] = [];
  return {
    rankCalls,
    totals: async (range) =>
      range.offset === 0 ? { masuk: 18_400_000, keluar: 12_040_000, daysRecorded: 12 } : { masuk: 16_000_000, keluar: 12_500_000, daysRecorded: 25 },
    byItem: async (options) => {
      rankCalls.push(options);
      return {
        rows: [
          { name: "Kopi susu", amount: 630_000, quantity: "42", unit: "porsi" },
          { name: "Es teh", amount: 90_000, quantity: "30", unit: null },
        ],
        daysRecorded: 6,
      };
    },
    byCategory: async (options) => {
      rankCalls.push(options);
      return { rows: [{ name: "Bensin", amount: 350_000, quantity: null, unit: null }], daysRecorded: 12 };
    },
    openBalances: async (kind) =>
      kind === "PIUTANG"
        ? { rows: [{ personName: "Pak Budi", remaining: 30_000 }, { personName: null, remaining: 15_000 }], total: 45_000 }
        : { rows: [], total: 0 },
  };
}

test("resolvesPeriodsOnBusinessDatesWithWeeksFromMonday", () => {
  const cases: [AskIntent["period"], number, string, string][] = [
    ["hari", 0, "2026-11-15", "2026-11-15"],
    ["hari", -1, "2026-11-14", "2026-11-14"],
    ["minggu", 0, "2026-11-09", "2026-11-15"],
    ["minggu", -1, "2026-11-02", "2026-11-08"],
    ["bulan", 0, "2026-11-01", "2026-11-15"],
    ["bulan", -1, "2026-10-01", "2026-10-31"],
    ["tahun", -1, "2025-01-01", "2025-12-31"],
  ];
  for (const [kind, offset, from, to] of cases) {
    const range = resolvePeriod(kind, offset, today);
    assert.deepEqual([range.from, range.to], [from, to], `${kind} ${offset}`);
  }
  assert.deepEqual(Object.values(resolvePeriod("bulan", -1, "2026-01-10")).slice(2), ["2025-12-01", "2025-12-31"]);
});

test("answersTotalsWithEveryNumberAsAFigure", async () => {
  const answer = await answerIntent(intent({}), today, fakeQueries());
  assert.equal(answer.answer, "Masuk bulan ini: {f0}. Keluar: {f1}. Untung: {f2}.");
  assert.deepEqual(answer.figures.map((figure) => [figure.key, figure.value, figure.unit]), [
    ["f0", 18_400_000, "IDR"],
    ["f1", 12_040_000, "IDR"],
    ["f2", 6_360_000, "IDR"],
  ]);
  assert.deepEqual([answer.daysRecorded, answer.period], [12, { from: "2026-11-01", to: "2026-11-15" }]);
  assert.doesNotMatch(answer.answer, /\d(?![^{]*\})/);
});

test("showsNoProfitForASingleDay", async () => {
  const answer = await answerIntent(intent({ period: "hari" }), today, fakeQueries());
  assert.equal(answer.answer, "Masuk hari ini: {f0}. Keluar: {f1}.");
});

test("answersMoneyInOnlyForAFollowUpAboutIncome", async () => {
  const answer = await answerIntent(intent({ direction: "IN", period: "tahun", periodOffset: -1 }), today, fakeQueries());
  assert.equal(answer.answer, "Masuk tahun lalu: {f0}.");
  assert.equal(answer.figures[0]?.value, 16_000_000);
});

test("listsTheBestSellersWithQuantityAndAmount", async () => {
  const queries = fakeQueries();
  const answer = await answerIntent(intent({ function: "byItem", period: "minggu" }), today, queries);
  assert.equal(answer.answer, "Paling laku minggu ini: Kopi susu {f0} ({f1}), Es teh {f2} ({f3}).");
  assert.deepEqual(answer.figures.map((figure) => [figure.value, figure.unit]), [[42, "porsi"], [630_000, "IDR"], [30, ""], [90_000, "IDR"]]);
  assert.deepEqual([queries.rankCalls[0]?.direction, queries.rankCalls[0]?.limit], ["IN", 3]);
});

test("asksForSpendingWhenACategoryIsNamed", async () => {
  const queries = fakeQueries();
  const answer = await answerIntent(intent({ function: "byCategory", name: "bensin" }), today, queries);
  assert.equal(answer.answer, "Bulan ini: Bensin {f0}.");
  assert.deepEqual([queries.rankCalls[0]?.direction, queries.rankCalls[0]?.name], ["OUT", "bensin"]);
});

test("comparesWithThePreviousPeriodAndSaysWhichWayItMoved", async () => {
  const answer = await answerIntent(intent({ function: "compare" }), today, fakeQueries());
  assert.equal(
    answer.answer,
    "Masuk bulan ini {f0}, bulan lalu {f1} (naik). Keluar bulan ini {f2}, bulan lalu {f3} (turun). Untung bulan ini {f4}, bulan lalu {f5} (naik).",
  );
});

test("listsWhoHasNotPaidAndTheTotal", async () => {
  const answer = await answerIntent(intent({ function: "openBalances", balance: "PIUTANG" }), today, fakeQueries());
  assert.equal(answer.answer, "Belum bayar: Pak Budi {f0}, Tanpa nama {f1}. Total {f2}.");
  const none = await answerIntent(intent({ function: "openBalances", balance: "UTANG" }), today, fakeQueries());
  assert.deepEqual([none.answer, none.figures], ["Tidak ada utang yang belum dibayar.", []]);
});

test("saysDatanyaBelumAdaForQuestionsTheDataCannotAnswer", async () => {
  const none = await answerIntent(intent({ function: "none" }), today, fakeQueries());
  assert.deepEqual([none.answer, none.figures], ["Datanya belum ada.", []]);
  const empty = { ...fakeQueries(), totals: async () => ({ masuk: 0, keluar: 0, daysRecorded: 0 }) };
  assert.equal((await answerIntent(intent({}), today, empty)).answer, "Datanya belum ada.");
});

afterEach(() => mock.restoreAll());

// The model's reply as text, wrapped the way the API returns it. Records each
// prompt the model was given.
function mockModelReplies(texts: string[]): string[] {
  const prompts: string[] = [];
  let calls = 0;
  mock.method(globalThis, "fetch", async (_url: string, init: RequestInit) => {
    const body = JSON.parse(String(init.body)) as { contents: { parts: { text: string }[] }[] };
    prompts.push(body.contents[0]?.parts[0]?.text ?? "");
    const reply = { candidates: [{ content: { parts: [{ text: texts[calls++] ?? "" }] } }], usageMetadata: { totalTokenCount: 50 } };
    return new Response(JSON.stringify(reply), { status: 200 });
  });
  mock.method(console, "warn", () => undefined);
  return prompts;
}

test("sendsThePreviousQuestionAsContextAndAnswersTheFollowUp", async () => {
  const prompts = mockModelReplies(['{"function":"totals","period":"tahun","periodOffset":-1,"direction":"IN"}']);
  const result = await askTanya({ question: "klo thn kmrn?", previousQuestion: "pemasukan bln ini brp?", todayBusinessDate: today, queries: fakeQueries() });
  assert.equal(prompts[0], "Pertanyaan sebelumnya: pemasukan bln ini brp?\nPertanyaan: klo thn kmrn?");
  assert.equal(result.isAnswered && result.answer, "Masuk tahun lalu: {f0}.");
});

test("retriesOnceWhenTheModelPicksAnUnknownFunctionThenGivesUp", async () => {
  mockModelReplies(['{"function":"forecast"}', '{"function":"cause"}']);
  const result = await askTanya({ question: "kenapa sepi?", previousQuestion: null, todayBusinessDate: today, queries: fakeQueries() });
  assert.equal(result.isAnswered, false);
});
