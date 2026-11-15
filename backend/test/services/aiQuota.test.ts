import { test } from "node:test";
import assert from "node:assert/strict";
import { hasReadsLeft, readLimit, readsUsedThisMonth, type QuotaStore } from "../../src/services/aiQuota.js";

const now = new Date("2026-11-20T05:00:00Z");

function store(overrides: Partial<QuotaStore>): QuotaStore {
  return {
    plan: "GRATIS",
    trialEndsAt: new Date("2026-11-10T00:00:00Z"),
    timezone: "Asia/Jakarta",
    aiReadsThisMonth: 0,
    aiReadsResetAt: new Date("2026-11-01T00:00:00Z"),
    ...overrides,
  };
}

test("allowsFiveReadsAMonthOnGratisAfterTheTrial", () => {
  assert.equal(hasReadsLeft(store({ aiReadsThisMonth: 4 }), now), true);
  assert.equal(hasReadsLeft(store({ aiReadsThisMonth: 5 }), now), false);
});

test("allowsThreeHundredOnProAndAThousandOnProPlus", () => {
  assert.deepEqual([readLimit(store({ plan: "PRO" }), now), readLimit(store({ plan: "PRO_PLUS" }), now)], [300, 1000]);
  assert.equal(hasReadsLeft(store({ plan: "PRO", aiReadsThisMonth: 299 }), now), true);
  assert.equal(hasReadsLeft(store({ plan: "PRO", aiReadsThisMonth: 300 }), now), false);
});

test("hasNoLimitDuringTheTrial", () => {
  const inTrial = store({ trialEndsAt: new Date("2026-11-25T00:00:00Z"), aiReadsThisMonth: 500 });
  assert.deepEqual([readLimit(inTrial, now), hasReadsLeft(inTrial, now)], [null, true]);
});

test("startsAgainFromZeroInANewMonthOfTheStoresCalendar", () => {
  const lastMonth = store({ aiReadsThisMonth: 5, aiReadsResetAt: new Date("2026-10-15T00:00:00Z") });
  assert.deepEqual([readsUsedThisMonth(lastMonth, now), hasReadsLeft(lastMonth, now)], [0, true]);
  // 18:00 UTC on 31 October is already 1 November in Jakarta.
  const countedOn31OctUtc = store({ aiReadsThisMonth: 5, aiReadsResetAt: new Date("2026-10-31T18:00:00Z") });
  assert.equal(readsUsedThisMonth(countedOn31OctUtc, now), 5);
  assert.equal(readsUsedThisMonth(store({ aiReadsThisMonth: 3, aiReadsResetAt: null }), now), 0);
});
