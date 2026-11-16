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

test("keepsTheHourAfterMidnightOnThePreviousBusinessDay", () => {
  // 00:00 and 00:30 WIB on 16 November. A formatter that reads midnight as hour
  // 24 would put these on 16 November.
  assert.equal(resolveBusinessDate({ now: new Date("2026-11-15T17:00:00Z"), ...jakarta }), "2026-11-15");
  assert.equal(resolveBusinessDate({ now: new Date("2026-11-15T17:30:00Z"), ...jakarta }), "2026-11-15");
  // 03:59:59 WIB is still the previous day.
  assert.equal(resolveBusinessDate({ now: new Date("2026-11-15T20:59:59Z"), ...jakarta }), "2026-11-15");
});

test("stepsBackAcrossAYearEndAndALeapDay", () => {
  // 01:00 WIB on 1 January 2027 and on 1 March 2028.
  assert.equal(resolveBusinessDate({ now: new Date("2026-12-31T18:00:00Z"), ...jakarta }), "2026-12-31");
  assert.equal(resolveBusinessDate({ now: new Date("2028-02-29T18:00:00Z"), ...jakarta }), "2028-02-29");
});

test("givesTheSameDateWhateverTimezoneTheServerRunsIn", () => {
  const serverTimezone = process.env.TZ;
  // The database host runs on +08:00 (#94). 03:30 WIB is 04:30 there, which is
  // already past the day change by the server's own clock.
  process.env.TZ = "Asia/Singapore";
  try {
    assert.equal(resolveBusinessDate({ now: new Date("2026-11-15T20:30:00Z"), ...jakarta }), "2026-11-15");
    assert.equal(localYearMonth(new Date("2026-11-30T16:30:00Z"), "Asia/Jakarta"), "2026-11");
  } finally {
    if (serverTimezone === undefined) {
      delete process.env.TZ;
    } else {
      process.env.TZ = serverTimezone;
    }
  }
});

test("namesTheCalendarMonthTheStoreIsIn", () => {
  // 18:00 UTC on 31 October is 01:00 WIB on 1 November.
  assert.equal(localYearMonth(new Date("2026-10-31T18:00:00Z"), "Asia/Jakarta"), "2026-11");
  assert.equal(localYearMonth(new Date("2026-10-31T16:00:00Z"), "Asia/Jakarta"), "2026-10");
});

test("comparesNamesIgnoringCaseAndExtraSpaces", () => {
  assert.equal(normaliseName("  Kopi   SUSU "), "kopi susu");
});
