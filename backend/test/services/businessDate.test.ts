import { test } from "node:test";
import assert from "node:assert/strict";
import { localYearMonth, resolveBusinessDate } from "../../src/services/businessDate.js";
import { normaliseName } from "../../src/services/normaliseName.js";

const jakarta = { timezone: "Asia/Jakarta", dayChangeHour: 4 };

test("keepsALateNightSaleOnThePreviousBusinessDay", () => {
  // 01:30 WIB on 16 November is 18:30 UTC on 15 November.
  assert.equal(resolveBusinessDate({ now: new Date("2026-11-15T18:30:00Z"), ...jakarta }), "2026-11-15");
  // 04:00 WIB starts the new day.
  assert.equal(resolveBusinessDate({ now: new Date("2026-11-15T21:00:00Z"), ...jakarta }), "2026-11-16");
});

test("usesTheStoresOwnTimezoneNotTheServers", () => {
  // 23:30 UTC on 15 November is 06:30 WIT on 16 November in Jayapura.
  const now = new Date("2026-11-15T23:30:00Z");
  assert.equal(resolveBusinessDate({ now, timezone: "Asia/Jayapura", dayChangeHour: 4 }), "2026-11-16");
  assert.equal(resolveBusinessDate({ now, timezone: "Asia/Jakarta", dayChangeHour: 4 }), "2026-11-16");
  assert.equal(resolveBusinessDate({ now: new Date("2026-11-15T19:30:00Z"), timezone: "Asia/Jakarta", dayChangeHour: 0 }), "2026-11-16");
});

test("namesTheCalendarMonthTheStoreIsIn", () => {
  // 18:00 UTC on 31 October is 01:00 WIB on 1 November.
  assert.equal(localYearMonth(new Date("2026-10-31T18:00:00Z"), "Asia/Jakarta"), "2026-11");
  assert.equal(localYearMonth(new Date("2026-10-31T16:00:00Z"), "Asia/Jakarta"), "2026-10");
});

test("comparesNamesIgnoringCaseAndExtraSpaces", () => {
  assert.equal(normaliseName("  Kopi   SUSU "), "kopi susu");
});
