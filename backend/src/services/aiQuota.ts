import { localYearMonth } from "./businessDate.js";

// Spec §18: AI reads (voice, photo, notebook, price list) and Tanya questions,
// each counted per calendar month in the store's timezone. The 14-day trial has
// no limit. Spec §12: only a read or answer that worked is counted.

export type Plan = "GRATIS" | "PRO" | "PRO_PLUS";

type PlanState = { plan: Plan; trialEndsAt: Date | null; timezone: string };

export type QuotaStore = PlanState & {
  aiReadsThisMonth: number;
  // When the count was last started from 0.
  aiReadsResetAt: Date | null;
};

export type QuestionStore = PlanState & { questionsThisMonth: number; questionsResetAt: Date | null };

const READ_LIMIT_BY_PLAN: Record<Plan, number> = { GRATIS: 5, PRO: 300, PRO_PLUS: 1000 };
// Tanya is not on Gratis at all.
const QUESTION_LIMIT_BY_PLAN: Record<Plan, number> = { GRATIS: 0, PRO: 300, PRO_PLUS: 1000 };

// The stored count belongs to an earlier month once the store's calendar month
// has moved on, so it reads as 0 without a nightly job.
export function isNewMonth(resetAt: Date | null, timezone: string, now: Date): boolean {
  return resetAt === null || localYearMonth(resetAt, timezone) !== localYearMonth(now, timezone);
}

export function readsUsedThisMonth(store: QuotaStore, now: Date): number {
  return isNewMonth(store.aiReadsResetAt, store.timezone, now) ? 0 : store.aiReadsThisMonth;
}

// Null means no limit.
export function readLimit(store: QuotaStore, now: Date): number | null {
  return isInTrial(store, now) ? null : READ_LIMIT_BY_PLAN[store.plan];
}

export function hasReadsLeft(store: QuotaStore, now: Date): boolean {
  const limit = readLimit(store, now);
  return limit === null || readsUsedThisMonth(store, now) < limit;
}

// The trial has everything (spec §18), so Tanya works in it on any plan.
export function isTanyaAvailable(store: PlanState, now: Date): boolean {
  return isInTrial(store, now) || QUESTION_LIMIT_BY_PLAN[store.plan] > 0;
}

export function hasQuestionsLeft(store: QuestionStore, now: Date): boolean {
  if (isInTrial(store, now)) {
    return true;
  }
  const used = isNewMonth(store.questionsResetAt, store.timezone, now) ? 0 : store.questionsThisMonth;
  return used < QUESTION_LIMIT_BY_PLAN[store.plan];
}

function isInTrial(store: PlanState, now: Date): boolean {
  return store.trialEndsAt !== null && store.trialEndsAt > now;
}
