import { test } from "node:test";
import assert from "node:assert/strict";
import { normalisePhone } from "../../src/services/phone.js";

test("storesEveryWayOfTypingTheSameNumberAsOneE164Number", () => {
  for (const typed of ["081234567890", "0812 3456 7890", "0812-3456-7890", "+62 812 3456 7890", "6281234567890", "81234567890"]) {
    assert.equal(normalisePhone(typed), "+6281234567890", typed);
  }
});

test("rejectsNumbersThatAreNotIndonesianMobiles", () => {
  for (const typed of ["0211234567", "+15555550123", "08123", "0812345678901234", "nomor saya", ""]) {
    assert.equal(normalisePhone(typed), null, typed);
  }
});
