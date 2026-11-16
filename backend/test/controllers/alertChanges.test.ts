import { test } from "node:test";
import assert from "node:assert/strict";

process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test-secret";
process.env.GEMMA_API_KEY = "test-key";
const { readAlertChanges } = await import("../../src/controllers/alertController.js");

function readFields(body: Record<string, unknown>): string[] {
  try {
    readAlertChanges(body);
    return [];
  } catch (error) {
    return Object.keys((error as { fields: Record<string, string> }).fields);
  }
}

test("readsJanganIngatkanAndSeen", () => {
  assert.deepEqual([readAlertChanges({ muted: true }), readAlertChanges({ seen: true, other: 1 })], [{ muted: true }, { seen: true }]);
});

test("refusesAnEmptyOrNonBooleanChange", () => {
  assert.deepEqual([readFields({}), readFields({ muted: "yes" })], [["muted"], ["muted"]]);
});
