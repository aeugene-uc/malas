import { ASK_SYSTEM_PROMPT, validateAskIntent, type AskIntent, type PeriodKind } from "../ai/askPrompt.js";
import { callModel } from "../ai/provider.js";

// Spec §7.8 "Tanya": the model picks a query, code runs it and writes the
// answer. Every number reaches the app as a figure behind a {fN} placeholder
// (#59), so none of them is ever written by the model. The answer compares and
// lists and never gives a cause.

export type PeriodRange = { kind: PeriodKind; offset: number; from: string; to: string };

export type Totals = { masuk: number; keluar: number; daysRecorded: number };

export type RankedRow = { name: string; amount: number; quantity: string | null; unit: string | null };

export type Ranked = { rows: RankedRow[]; daysRecorded: number };

export type OpenBalances = { rows: { personName: string | null; remaining: number }[]; total: number };

export type RankOptions = { range: PeriodRange; direction: "IN" | "OUT"; name: string | null; limit: number };

// The database half (S7's queries) provides these. Every amount is integer
// rupiah computed by §10's rules.
export type TanyaQueries = {
  totals(range: PeriodRange): Promise<Totals>;
  byItem(options: RankOptions): Promise<Ranked>;
  byCategory(options: RankOptions): Promise<Ranked>;
  openBalances(kind: "PIUTANG" | "UTANG"): Promise<OpenBalances>;
};

export type TanyaFigure = { key: string; label: string; value: number; unit: string };

export type TanyaAnswer = {
  answer: string;
  figures: TanyaFigure[];
  daysRecorded: number | null;
  period: { from: string; to: string } | null;
  function: AskIntent["function"];
};

export type AskResult =
  | ({ isAnswered: true; model: string; tokens: number } & TanyaAnswer)
  | { isAnswered: false; failures: string[] };

type AskOptions = {
  question: string;
  // The last question on the Tanya screen, for follow-ups (#183).
  previousQuestion: string | null;
  todayBusinessDate: string;
  queries: TanyaQueries;
};

const NO_DATA = "Datanya belum ada.";
const TOP_ROWS = 3;
const TOP_BALANCES = 5;

export async function askTanya(options: AskOptions): Promise<AskResult> {
  const userText =
    options.previousQuestion === null
      ? `Pertanyaan: ${options.question}`
      : `Pertanyaan sebelumnya: ${options.previousQuestion}\nPertanyaan: ${options.question}`;
  const reply = await callModel({ systemPrompt: ASK_SYSTEM_PROMPT, userText }, validateAskIntent);
  if (!reply.isRead) {
    return { isAnswered: false, failures: reply.failures };
  }
  const answer = await answerIntent(reply.data, options.todayBusinessDate, options.queries);
  return { isAnswered: true, model: reply.model, tokens: reply.tokens, ...answer };
}

export async function answerIntent(intent: AskIntent, todayBusinessDate: string, queries: TanyaQueries): Promise<TanyaAnswer> {
  const range = resolvePeriod(intent.period, intent.periodOffset, todayBusinessDate);
  switch (intent.function) {
    case "totals":
      return answerTotals(intent, range, queries);
    case "byItem":
    case "byCategory":
      return answerRanked(intent, range, queries);
    case "compare":
      return answerCompare(intent, range, todayBusinessDate, queries);
    case "openBalances":
      return answerOpenBalances(intent, queries);
    case "none":
      return noData(intent, null);
  }
}

async function answerTotals(intent: AskIntent, range: PeriodRange, queries: TanyaQueries): Promise<TanyaAnswer> {
  const totals = await queries.totals(range);
  if (totals.daysRecorded === 0) {
    return noData(intent, range);
  }
  const figures = new FigureList();
  const label = periodLabel(range);
  let answer: string;
  if (intent.direction === "IN") {
    answer = `Masuk ${label}: ${figures.money("Masuk", totals.masuk)}.`;
  } else if (intent.direction === "OUT") {
    answer = `Keluar ${label}: ${figures.money("Keluar", totals.keluar)}.`;
  } else {
    answer = `Masuk ${label}: ${figures.money("Masuk", totals.masuk)}. Keluar: ${figures.money("Keluar", totals.keluar)}.`;
    // Spec §7.6: a single day shows no profit, so a big purchase does not read as a loss.
    if (range.kind !== "hari") {
      answer += ` Untung: ${figures.money("Untung", totals.masuk - totals.keluar)}.`;
    }
  }
  return { answer, figures: figures.all(), daysRecorded: totals.daysRecorded, period: periodOf(range), function: intent.function };
}

async function answerRanked(intent: AskIntent, range: PeriodRange, queries: TanyaQueries): Promise<TanyaAnswer> {
  const isByItem = intent.function === "byItem";
  // "Paling laku" is about sales, "habis untuk" about spending.
  const direction = intent.direction ?? (isByItem ? "IN" : "OUT");
  const rankOptions: RankOptions = { range, direction, name: intent.name, limit: TOP_ROWS };
  const ranked = isByItem ? await queries.byItem(rankOptions) : await queries.byCategory(rankOptions);
  if (ranked.rows.length === 0 || ranked.daysRecorded === 0) {
    return noData(intent, range);
  }
  const figures = new FigureList();
  const label = periodLabel(range);
  const rowTexts = ranked.rows.map((row) => {
    const quantity = row.quantity === null ? null : figures.quantity(row.name, row.quantity, row.unit);
    const amount = figures.money(row.name, row.amount);
    return quantity === null ? `${row.name} ${amount}` : `${row.name} ${quantity} (${amount})`;
  });
  const heading = intent.name !== null ? capitalise(label) : `${rankedHeading(isByItem, direction)} ${label}`;
  const answer = `${heading}: ${rowTexts.join(", ")}.`;
  return { answer, figures: figures.all(), daysRecorded: ranked.daysRecorded, period: periodOf(range), function: intent.function };
}

async function answerCompare(
  intent: AskIntent,
  range: PeriodRange,
  todayBusinessDate: string,
  queries: TanyaQueries,
): Promise<TanyaAnswer> {
  const otherRange = resolvePeriod(intent.period, intent.comparePeriodOffset ?? intent.periodOffset - 1, todayBusinessDate);
  const [current, other] = await Promise.all([queries.totals(range), queries.totals(otherRange)]);
  if (current.daysRecorded === 0 && other.daysRecorded === 0) {
    return noData(intent, range);
  }
  const figures = new FigureList();
  const labelA = periodLabel(range);
  const labelB = periodLabel(otherRange);
  const lines: [string, number, number][] = [
    ["Masuk", current.masuk, other.masuk],
    ["Keluar", current.keluar, other.keluar],
  ];
  if (range.kind !== "hari") {
    lines.push(["Untung", current.masuk - current.keluar, other.masuk - other.keluar]);
  }
  const selected = lines.filter(([name]) => intent.direction === null || name === (intent.direction === "IN" ? "Masuk" : "Keluar"));
  const answer = selected
    .map(([name, a, b]) => `${name} ${labelA} ${figures.money(`${name} ${labelA}`, a)}, ${labelB} ${figures.money(`${name} ${labelB}`, b)} (${trendWord(a, b)}).`)
    .join(" ");
  return { answer, figures: figures.all(), daysRecorded: current.daysRecorded, period: periodOf(range), function: intent.function };
}

async function answerOpenBalances(intent: AskIntent, queries: TanyaQueries): Promise<TanyaAnswer> {
  const figures = new FigureList();
  const kind = intent.balance ?? "BOTH";
  if (kind === "BOTH") {
    const [piutang, utang] = await Promise.all([queries.openBalances("PIUTANG"), queries.openBalances("UTANG")]);
    const answer = `Piutang ${figures.money("Piutang", piutang.total)} · Utang ${figures.money("Utang", utang.total)}.`;
    return { answer, figures: figures.all(), daysRecorded: null, period: null, function: intent.function };
  }
  const balances = await queries.openBalances(kind);
  if (balances.rows.length === 0) {
    const answer = kind === "PIUTANG" ? "Tidak ada yang belum bayar." : "Tidak ada utang yang belum dibayar.";
    return { answer, figures: [], daysRecorded: null, period: null, function: intent.function };
  }
  const rowTexts = balances.rows.slice(0, TOP_BALANCES).map((row) => {
    const name = row.personName ?? "Tanpa nama";
    return `${name} ${figures.money(name, row.remaining)}`;
  });
  const heading = kind === "PIUTANG" ? "Belum bayar" : "Belum dibayar ke";
  const answer = `${heading}: ${rowTexts.join(", ")}. Total ${figures.money("Total", balances.total)}.`;
  return { answer, figures: figures.all(), daysRecorded: null, period: null, function: intent.function };
}

function rankedHeading(isByItem: boolean, direction: "IN" | "OUT"): string {
  if (isByItem) {
    return direction === "IN" ? "Paling laku" : "Belanja terbesar";
  }
  return direction === "OUT" ? "Keluar terbesar" : "Masuk terbesar";
}

function noData(intent: AskIntent, range: PeriodRange | null): TanyaAnswer {
  return { answer: NO_DATA, figures: [], daysRecorded: null, period: range === null ? null : periodOf(range), function: intent.function };
}

// Collects figures and hands back their placeholders in order: {f0}, {f1}, ...
class FigureList {
  private readonly figures: TanyaFigure[] = [];

  money(label: string, rupiah: number): string {
    return this.add({ label, value: rupiah, unit: "IDR" });
  }

  quantity(label: string, quantity: string, unit: string | null): string {
    return this.add({ label, value: Number(quantity), unit: unit ?? "" });
  }

  all(): TanyaFigure[] {
    return this.figures;
  }

  private add(figure: Omit<TanyaFigure, "key">): string {
    const key = `f${this.figures.length}`;
    this.figures.push({ key, ...figure });
    return `{${key}}`;
  }
}

function trendWord(current: number, other: number): string {
  if (current === other) {
    return "sama";
  }
  return current > other ? "naik" : "turun";
}

// Calendar periods on business dates. A week runs Monday to Sunday, as in
// Analisis (F7). The current period ends today.
export function resolvePeriod(kind: PeriodKind, offset: number, todayBusinessDate: string): PeriodRange {
  const today = new Date(`${todayBusinessDate}T00:00:00Z`);
  let from: Date;
  let to: Date;
  if (kind === "hari") {
    from = shiftDays(today, offset);
    to = from;
  } else if (kind === "minggu") {
    const daysSinceMonday = (today.getUTCDay() + 6) % 7;
    from = shiftDays(today, offset * 7 - daysSinceMonday);
    to = shiftDays(from, 6);
  } else if (kind === "bulan") {
    from = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth() + offset, 1));
    to = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth() + offset + 1, 0));
  } else {
    from = new Date(Date.UTC(today.getUTCFullYear() + offset, 0, 1));
    to = new Date(Date.UTC(today.getUTCFullYear() + offset, 11, 31));
  }
  const toDate = toIsoDate(to);
  return { kind, offset, from: toIsoDate(from), to: toDate > todayBusinessDate ? todayBusinessDate : toDate };
}

const LABELS: Record<PeriodKind, [current: string, previous: string, unit: string]> = {
  hari: ["hari ini", "kemarin", "hari"],
  minggu: ["minggu ini", "minggu lalu", "minggu"],
  bulan: ["bulan ini", "bulan lalu", "bulan"],
  tahun: ["tahun ini", "tahun lalu", "tahun"],
};

function periodLabel(range: PeriodRange): string {
  const [current, previous, unit] = LABELS[range.kind];
  if (range.offset === 0) {
    return current;
  }
  return range.offset === -1 ? previous : `${-range.offset} ${unit} lalu`;
}

function periodOf(range: PeriodRange): { from: string; to: string } {
  return { from: range.from, to: range.to };
}

function capitalise(text: string): string {
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function shiftDays(date: Date, days: number): Date {
  const moved = new Date(date);
  moved.setUTCDate(moved.getUTCDate() + days);
  return moved;
}

function toIsoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}
