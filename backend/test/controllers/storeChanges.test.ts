import { test } from "node:test";
import assert from "node:assert/strict";
import type { Request } from "express";

process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test-secret";
const { readStoreChanges } = await import("../../src/controllers/storeController.js");
const { readBody } = await import("../../src/controllers/validate.js");
const { FIXED_CATEGORIES, fixedCategoryRows } = await import("../../src/services/categories.js");

test("readsFirstRunSetupAsF2SendsIt", () => {
  assert.deepEqual(readStoreChanges({ name: "  Warung Bu Sari ", businessTypes: ["MAKANAN_MINUMAN", "JUALAN_BARANG"] }), {
    name: "Warung Bu Sari",
    businessTypes: ["MAKANAN_MINUMAN", "JUALAN_BARANG"],
  });
});

test("readsSettingsAsF9SendsThemAndSortsTheClosedDays", () => {
  const changes = readStoreChanges({
    businessTypes: ["JASA"],
    closedDays: [7, 1],
    dayChangeHour: 3,
    reminderTime: "20:00",
    alertsOn: false,
    plan: "PRO",
    unknownField: "ignored",
  });
  assert.deepEqual(changes, { businessTypes: ["JASA"], closedDays: [1, 7], dayChangeHour: 3, reminderTime: "20:00", alertsOn: false, plan: "PRO" });
  assert.deepEqual(readStoreChanges({ reminderTime: null }), { reminderTime: null });
});

test("rejectsEveryWrongFieldAtOnce", () => {
  try {
    readStoreChanges({
      name: "",
      businessTypes: ["WARUNG"],
      closedDays: [1, 2, 3, 4, 5, 6, 7],
      timezone: "Asia/Singapore",
      dayChangeHour: 9,
      reminderTime: "8 malam",
      alertsOn: "ya",
      plan: "GRATIS_SELAMANYA",
    });
    assert.fail("expected a validation error");
  } catch (error) {
    const fields = (error as { fields: Record<string, string> }).fields;
    assert.deepEqual(Object.keys(fields).sort(), ["alertsOn", "businessTypes", "closedDays", "dayChangeHour", "name", "plan", "reminderTime", "timezone"]);
  }
});

test("rejectsDuplicateOrEmptyChoices", () => {
  assert.throws(() => readStoreChanges({ businessTypes: [] }));
  assert.throws(() => readStoreChanges({ businessTypes: ["JASA", "JASA"] }));
  assert.throws(() => readStoreChanges({ closedDays: [1, 1] }));
  assert.throws(() => readStoreChanges({ closedDays: [0] }));
});

test("refusesABodyThatCarriesAStoreId", () => {
  assert.throws(() => readBody({ body: { storeId: "store-2", name: "x" } } as Request), /storeId/);
});

test("givesEveryStoreTheFourteenFixedCategoriesOfSpec42", () => {
  assert.equal(FIXED_CATEGORIES.length, 14);
  const keys = FIXED_CATEGORIES.map((category) => `${category.direction}|${category.name}`);
  assert.equal(new Set(keys).size, keys.length);
  const notInProfit = FIXED_CATEGORIES.filter((category) => !category.countedInProfit).map((category) => category.name);
  assert.deepEqual(notInProfit, ["Modal masuk", "Ambil pribadi", "Pinjaman masuk", "Bayar pinjaman", "Uang titipan", "Uang titipan"]);
  assert.ok(fixedCategoryRows().every((row) => row.fixed));
});
