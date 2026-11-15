import { readText } from "./readPrompt.js";

// Spec §7.8 and §9 "Tanya": the model only picks one of 5 query functions and
// its parameters. Code runs the query and writes the answer, so every number
// the owner reads comes from code (#59).

export type TanyaFunction = "totals" | "byItem" | "byCategory" | "compare" | "openBalances" | "none";
export type PeriodKind = "hari" | "minggu" | "bulan" | "tahun";
export type BalanceKind = "PIUTANG" | "UTANG" | "BOTH";

export type AskIntent = {
  function: TanyaFunction;
  period: PeriodKind;
  // 0 is the current period, -1 the one before ("bulan lalu").
  periodOffset: number;
  // For compare: the period to compare against, usually periodOffset - 1.
  comparePeriodOffset: number | null;
  direction: "IN" | "OUT" | null;
  // An item or category the question names ("bensin").
  name: string | null;
  balance: BalanceKind | null;
};

const FUNCTIONS: TanyaFunction[] = ["totals", "byItem", "byCategory", "compare", "openBalances", "none"];
const PERIODS: PeriodKind[] = ["hari", "minggu", "bulan", "tahun"];
const BALANCES: BalanceKind[] = ["PIUTANG", "UTANG", "BOTH"];

export const ASK_SYSTEM_PROMPT = `You route a small-business owner's question, in everyday Indonesian, to one query over their own bookkeeping records. Return ONLY a JSON object, no explanation and no code fence:

{"function":"totals"|"byItem"|"byCategory"|"compare"|"openBalances"|"none","period":"hari"|"minggu"|"bulan"|"tahun","periodOffset":number,"comparePeriodOffset":number|null,"direction":"IN"|"OUT"|null,"name":string|null,"balance":"PIUTANG"|"UTANG"|"BOTH"|null}

You never answer the question and never write a number from the records. Code runs the query and writes the answer.

Functions:
- totals: money in, money out or profit for one period ("pemasukan bulan ini brp?", "untung minggu ini?").
- byItem: what sold most, or how much of one item ("apa yang paling laku minggu ini?", "kopi terjual berapa hari ini?").
- byCategory: spending or income by kind ("berapa habis untuk bensin bulan ini?", "keluar paling banyak buat apa?").
- compare: one period against another ("bulan ini dibanding bulan lalu gimana?").
- openBalances: who still owes or is owed ("siapa yang belum bayar?" is PIUTANG, "utang saya ke siapa aja?" is UTANG).
- none: anything else, including causes ("kenapa sepi?"), advice, the future, or questions about other businesses.

Fields:
- period and periodOffset: "hari ini" is hari 0, "kemarin" hari -1, "minggu ini" minggu 0, "minggu lalu" minggu -1, "bulan lalu" bulan -1, "tahun kemarin" or "thn kmrn" tahun -1. When no time is said, use bulan 0.
- comparePeriodOffset: only for compare. When only one period is said, compare it with the one before it.
- direction: IN for sales and money in, OUT for spending and money out, null for both.
- name: the item or category the question names, written as the owner wrote it, else null.
- balance: only for openBalances.

A message may include the previous question. Use it only to fill in what the new question leaves out: after "pemasukan bln ini brp?", the question "klo thn kmrn?" means totals, direction IN, tahun -1. If the new question stands on its own, ignore the previous one.`;

// The model's reply is a trust boundary (CLAUDE.md), so every field is checked
// and anything outside the contract throws. callModel then retries once.
export function validateAskIntent(value: unknown): AskIntent {
  const reply = (value ?? {}) as Record<string, unknown>;
  const fn = pickFrom(FUNCTIONS, reply.function, "function");
  const direction = reply.direction ?? null;
  if (direction !== null && direction !== "IN" && direction !== "OUT") {
    throw new Error("direction must be IN, OUT or null");
  }
  return {
    function: fn,
    period: reply.period == null ? "bulan" : pickFrom(PERIODS, reply.period, "period"),
    periodOffset: readOffset(reply.periodOffset ?? 0, "periodOffset"),
    comparePeriodOffset: reply.comparePeriodOffset == null ? null : readOffset(reply.comparePeriodOffset, "comparePeriodOffset"),
    direction,
    name: readText(reply.name, "name"),
    balance: reply.balance == null ? null : pickFrom(BALANCES, reply.balance, "balance"),
  };
}

function pickFrom<T extends string>(allowed: T[], value: unknown, path: string): T {
  const match = allowed.find((candidate) => candidate === value);
  if (match === undefined) {
    throw new Error(`${path} must be one of ${allowed.join(", ")}`);
  }
  return match;
}

// Only the past and the present can be asked about.
function readOffset(value: unknown, path: string): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value > 0 || value < -50) {
    throw new Error(`${path} must be a whole number from -50 to 0`);
  }
  return value;
}
