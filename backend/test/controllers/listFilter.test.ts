import { test } from "node:test";
import assert from "node:assert/strict";

process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test-secret";
process.env.GEMMA_API_KEY = "test-key";
const { readListFilter } = await import("../../src/controllers/transactionController.js");
const { isOpenAs } = await import("../../src/services/transactionQueries.js");

function readFields(query: Record<string, unknown>): string[] {
  try {
    readListFilter(query);
    return [];
  } catch (error) {
    return Object.keys((error as { fields: Record<string, string> }).fields);
  }
}

test("readsCatatansFiltersFromTheQuery", () => {
  const filter = readListFilter({ direction: "OUT", unpaid: "true", q: "  budi ", from: "2026-11-01", itemId: "", cursor: "ckx1" });
  assert.deepEqual(filter, { from: "2026-11-01", to: null, direction: "OUT", itemId: null, categoryId: null, personId: null, isUnpaidOnly: true, q: "budi", cursor: "ckx1" });
});

test("refusesAFilterThatIsNotOne", () => {
  assert.deepEqual(readFields({ direction: "both", unpaid: "yes", to: "2026-13-01" }).sort(), ["direction", "to", "unpaid"]);
});

test("putsKembalikanUnderUtangAndOnlyUnpaidMoneyInUnderPiutang", () => {
  const rows = [
    { direction: "IN" as const, remaining: 30000 },
    { direction: "IN" as const, remaining: -20000 },
    { direction: "OUT" as const, remaining: 50000 },
    { direction: "OUT" as const, remaining: 0 },
  ];
  assert.deepEqual(rows.map((row) => [isOpenAs(row, "PIUTANG"), isOpenAs(row, "UTANG")]), [[true, false], [false, true], [false, true], [false, false]]);
});
