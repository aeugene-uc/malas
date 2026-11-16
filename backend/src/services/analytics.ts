// Pure rules for Beranda and Analisis (spec §6, §7.6, §10), tested without a
// database. Dates are "YYYY-MM-DD" business dates; nothing here reads a clock.

export type AnalysisPeriod = "minggu" | "bulan" | "tahun";

export type DateRange = { from: string; to: string };

// The period that starts at (or contains) `start`: a week from Monday, a
// calendar month, or a calendar year. The current period ends today.
export function periodFromStart(kind: AnalysisPeriod, start: string, today: string): DateRange {
  const full = fullPeriod(kind, start);
  return { from: full.from, to: full.to > today ? today : full.to };
}

// The whole period before, not cut at today, so "bulan lalu" is a full month.
export function previousPeriod(kind: AnalysisPeriod, start: string): DateRange {
  const current = fullPeriod(kind, start);
  return fullPeriod(kind, addDays(current.from, -1));
}

function fullPeriod(kind: AnalysisPeriod, start: string): DateRange {
  const date = toDate(start);
  if (kind === "minggu") {
    const daysSinceMonday = (date.getUTCDay() + 6) % 7;
    const monday = addDays(start, -daysSinceMonday);
    return { from: monday, to: addDays(monday, 6) };
  }
  if (kind === "bulan") {
    const year = date.getUTCFullYear();
    const month = date.getUTCMonth();
    return { from: toIso(new Date(Date.UTC(year, month, 1))), to: toIso(new Date(Date.UTC(year, month + 1, 0))) };
  }
  const year = date.getUTCFullYear();
  return { from: `${year}-01-01`, to: `${year}-12-31` };
}

// Spec §10: change = (this period - previous period) / previous period. No
// previous figure gives null, which the app shows as "—", never 0% or infinity.
// Dividing by the size of the previous figure keeps "up" positive when the
// previous profit was a loss.
export function changeRatio(current: number, previous: number): number | null {
  if (previous === 0) {
    return null;
  }
  return Math.round(((current - previous) / Math.abs(previous)) * 10_000) / 10_000;
}

export function countOpenDays(range: DateRange, closedDays: number[]): number {
  return openDates(range, closedDays).length;
}

// Spec §6 "Belum dicatat": open days with no entry. Closed days never count.
export function missedDays(range: DateRange, recordedDates: Set<string>, closedDays: number[]): string[] {
  return openDates(range, closedDays).filter((date) => !recordedDates.has(date));
}

function openDates(range: DateRange, closedDays: number[]): string[] {
  const dates: string[] = [];
  for (let date = range.from; date <= range.to; date = addDays(date, 1)) {
    if (!closedDays.includes(isoWeekday(date))) {
      dates.push(date);
    }
  }
  return dates;
}

export type RankLine = {
  lineTotal: number;
  countedInProfit: boolean | null;
  item: { id: string; name: string } | null;
  category: { id: string; name: string } | null;
};

// kind tells Catatan whether to filter by itemId or categoryId (#262). Lines
// with no category share one row with id null, which Catatan cannot filter on.
export type ShareRow = { kind: "item" | "category"; id: string | null; name: string; amount: number; share: number };

type RankTarget = Omit<ShareRow, "amount" | "share">;

// Spec §7.6: money in by item, and money out by category and expense item. In
// "category" mode a line with an item counts under the item (Gas), and a line
// without one under its category (Sewa). Money not counted in profit is left
// out; it has its own line in the summary.
export function rankLines(lines: RankLine[], mode: "item" | "category"): ShareRow[] {
  const rowsByKey = new Map<string, RankTarget & { amount: number }>();
  for (const line of lines) {
    if (line.countedInProfit === false) {
      continue;
    }
    const target = findRankTarget(line, mode);
    if (target === null) {
      continue;
    }
    const key = `${target.kind}:${target.id ?? ""}`;
    const row = rowsByKey.get(key) ?? { ...target, amount: 0 };
    row.amount += line.lineTotal;
    rowsByKey.set(key, row);
  }
  const total = [...rowsByKey.values()].reduce((sum, row) => sum + row.amount, 0);
  return [...rowsByKey.values()]
    .map((row) => ({ ...row, share: total === 0 ? 0 : Math.round((row.amount / total) * 10_000) / 10_000 }))
    .sort((a, b) => b.amount - a.amount);
}

function findRankTarget(line: RankLine, mode: "item" | "category"): RankTarget | null {
  if (line.item !== null) {
    return { kind: "item", ...line.item };
  }
  if (mode === "item") {
    return null;
  }
  return line.category === null ? { kind: "category", id: null, name: "Tanpa kategori" } : { kind: "category", ...line.category };
}

const WEEKDAY_NAMES = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"];

// "Selasa" for the comparison "Selasa lalu" on Beranda (spec §6).
export function weekdayName(date: string): string {
  return WEEKDAY_NAMES[toDate(date).getUTCDay()] as string;
}

export function addDays(date: string, days: number): string {
  const moved = toDate(date);
  moved.setUTCDate(moved.getUTCDate() + days);
  return toIso(moved);
}

// 1 is Monday and 7 is Sunday, as closedDays stores them.
function isoWeekday(date: string): number {
  const day = toDate(date).getUTCDay();
  return day === 0 ? 7 : day;
}

function toDate(date: string): Date {
  return new Date(`${date}T00:00:00Z`);
}

function toIso(date: Date): string {
  return date.toISOString().slice(0, 10);
}
