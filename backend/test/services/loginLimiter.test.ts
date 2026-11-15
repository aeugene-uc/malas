import { test } from "node:test";
import assert from "node:assert/strict";
import { LoginLimiter } from "../../src/services/loginLimiter.js";

const minute = 60_000;

test("locksANumberForFifteenMinutesAfterFiveWrongTries", () => {
  const limiter = new LoginLimiter();
  for (let attempt = 0; attempt < 4; attempt++) {
    limiter.recordFailure("+6281234567890", attempt * minute);
  }
  assert.equal(limiter.lockRemainingMs("+6281234567890", 4 * minute), 0);
  limiter.recordFailure("+6281234567890", 4 * minute);
  assert.equal(limiter.lockRemainingMs("+6281234567890", 5 * minute), 14 * minute);
  assert.equal(limiter.lockRemainingMs("+6281234567890", 19 * minute), 0);
});

test("onlyCountsWrongTriesWithinFifteenMinutes", () => {
  const limiter = new LoginLimiter();
  for (let attempt = 0; attempt < 4; attempt++) {
    limiter.recordFailure("+6281234567890", attempt * minute);
  }
  limiter.recordFailure("+6281234567890", 20 * minute);
  assert.equal(limiter.lockRemainingMs("+6281234567890", 20 * minute), 0);
});

test("clearsTheCountOnASuccessfulSignInAndKeepsNumbersApart", () => {
  const limiter = new LoginLimiter();
  for (let attempt = 0; attempt < 4; attempt++) {
    limiter.recordFailure("+6281234567890", 0);
    limiter.recordFailure("+6289900001111", 0);
  }
  limiter.recordSuccess("+6281234567890");
  limiter.recordFailure("+6281234567890", 0);
  limiter.recordFailure("+6289900001111", 0);
  assert.equal(limiter.lockRemainingMs("+6281234567890", 0), 0);
  assert.equal(limiter.lockRemainingMs("+6289900001111", 0), 15 * minute);
});
