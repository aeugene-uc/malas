// Stops password guessing on one phone number (#198): after 5 wrong tries in 15
// minutes, that number is locked for 15 minutes.
//
// The counts live in this process's memory, so a restart clears them and two
// server processes would each keep their own. That is enough for the MVP's
// single backend process. A shared store comes with production (S16, #27).

const MAX_FAILURES = 5;
const WINDOW_MS = 15 * 60 * 1000;
const LOCK_MS = 15 * 60 * 1000;
// Old entries are swept once the map grows past this, so it cannot grow forever.
const SWEEP_AT_SIZE = 1000;

type Attempts = { failures: number; windowStart: number; lockedUntil: number };

export class LoginLimiter {
  private readonly attemptsByPhone = new Map<string, Attempts>();

  // Milliseconds left on the lock, or 0 when the number may try.
  lockRemainingMs(phoneKey: string, nowMs: number): number {
    const attempts = this.attemptsByPhone.get(phoneKey);
    return attempts === undefined ? 0 : Math.max(0, attempts.lockedUntil - nowMs);
  }

  recordFailure(phoneKey: string, nowMs: number): void {
    const attempts = this.attemptsByPhone.get(phoneKey);
    if (attempts === undefined || nowMs - attempts.windowStart > WINDOW_MS) {
      this.attemptsByPhone.set(phoneKey, { failures: 1, windowStart: nowMs, lockedUntil: 0 });
    } else {
      attempts.failures += 1;
      if (attempts.failures >= MAX_FAILURES) {
        attempts.lockedUntil = nowMs + LOCK_MS;
        attempts.failures = 0;
        attempts.windowStart = nowMs;
      }
    }
    if (this.attemptsByPhone.size > SWEEP_AT_SIZE) {
      this.sweep(nowMs);
    }
  }

  recordSuccess(phoneKey: string): void {
    this.attemptsByPhone.delete(phoneKey);
  }

  private sweep(nowMs: number): void {
    for (const [phoneKey, attempts] of this.attemptsByPhone) {
      if (attempts.lockedUntil <= nowMs && nowMs - attempts.windowStart > WINDOW_MS) {
        this.attemptsByPhone.delete(phoneKey);
      }
    }
  }
}
