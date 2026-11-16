import { test } from "node:test";
import assert from "node:assert/strict";

process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test-secret";
process.env.GEMMA_API_KEY = "test-key";
const { isCalendarDate, readSaveRequest } = await import("../../src/controllers/transactionController.js");

const KETIK_BODY = {
  direction: "IN",
  total: 1200000,
  personId: null,
  personName: null,
  dueDate: null,
  source: "TYPED",
  inputId: null,
  note: null,
  lines: [{ itemId: null, itemName: null, categoryId: "cat-1", quantity: null, unit: null, unitPrice: null, lineTotal: 1200000 }],
  payments: [{ date: "2026-11-16", amount: 1200000, label: "cash" }],
};

function readFields(body: Record<string, unknown>): string[] {
  try {
    readSaveRequest(body);
    return [];
  } catch (error) {
    return Object.keys((error as { fields: Record<string, string> }).fields);
  }
}

test("readsKetiksBodyWithNoDateAsToday", () => {
  const request = readSaveRequest(KETIK_BODY);
  assert.deepEqual([request.businessDate, request.direction, request.source, request.lines[0]?.lineTotal, request.payments[0]?.amount], [null, "IN", "TYPED", 1200000, 1200000]);
});

test("acceptsNullPricesBecauseAnUnclearLineIsFlaggedNotRefused", () => {
  const lines = [{ itemId: null, itemName: "Es teh", categoryId: null, quantity: "25", unit: null, unitPrice: null, lineTotal: null }];
  assert.deepEqual(readFields({ ...KETIK_BODY, total: 0, lines }), []);
});

test("acceptsANegativeReturQuantityAndHalfAKilo", () => {
  const lines = [
    { itemId: null, itemName: "Gula", categoryId: null, quantity: "-2", unit: "kg", unitPrice: 15000, lineTotal: null },
    { itemId: null, itemName: "Gula", categoryId: null, quantity: "0.5", unit: "kg", unitPrice: 15000, lineTotal: null },
  ];
  assert.deepEqual(readFields({ ...KETIK_BODY, lines }), []);
});

test("treatsABlankPersonNameAsNoPerson", () => {
  assert.equal(readSaveRequest({ ...KETIK_BODY, personName: "   " }).personName, null);
});

test("refusesAMalformedBodyNamingEveryWrongField", () => {
  const fields = readFields({
    ...KETIK_BODY,
    direction: "SIDEWAYS",
    businessDate: "2026-02-30",
    total: 12.5,
    source: "FAX",
    lines: [{ quantity: "1,5", unitPrice: -1, lineTotal: "12000" }],
    payments: [{ date: "kemarin", amount: 0 }],
  });
  assert.deepEqual(fields.sort(), [
    "businessDate",
    "direction",
    "lines.0.lineTotal",
    "lines.0.quantity",
    "lines.0.unitPrice",
    "payments.0.amount",
    "payments.0.date",
    "source",
    "total",
  ]);
});

test("refusesAnEntryWithNoLinesAndNoAmount", () => {
  assert.deepEqual(readFields({ ...KETIK_BODY, total: null, lines: [] }), ["lines"]);
});

test("knowsWhichDatesAreRealDays", () => {
  assert.deepEqual([isCalendarDate("2028-02-29"), isCalendarDate("2026-02-29"), isCalendarDate("2026-11-16T00:00:00Z")], [true, false, false]);
});
