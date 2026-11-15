import { localYearMonth } from "./businessDate.js";

// Spec §18: AI reads (voice, photo, notebook, price list) per calendar month in
// the store's timezone. The 14-day trial has no limit. Spec §12: only a read that
// succeeds is counted.

export type Plan = "GRATIS" | "PRO" | "PRO_PLUS";

export type QuotaStore = {
  plan: Plan;
  trialEndsAt: Date | null;
  timezone: string;
  aiReadsThisMonth: number;
  // When the count was last started from 0.
  aiReadsResetAt: Date | null;
};

const READ_LIMIT_BY_PLAN: Record<Plan, number> = { GRATIS: 5, PRO: 300, PRO_PLUS: 1000 };

// The stored count belongs to an earlier month once the store's calendar month
// has moved on, so it reads as 0 without a nightly job.
export function readsUsedThisMonth(store: QuotaStore, now: Date): number {
  const isCountFromThisMonth =
    store.aiReadsResetAt !== null && localYearMonth(store.aiReadsResetAt, store.timezone) === localYearMonth(now, store.timezone);
  return isCountFromThisMonth ? store.aiReadsThisMonth : 0;
}

// Null means no limit.
export function readLimit(store: QuotaStore, now: Date): number | null {
  const isInTrial = store.trialEndsAt !== null && store.trialEndsAt > now;
  return isInTrial ? null : READ_LIMIT_BY_PLAN[store.plan];
}

export function hasReadsLeft(store: QuotaStore, now: Date): boolean {
  const limit = readLimit(store, now);
  return limit === null || readsUsedThisMonth(store, now) < limit;
}
