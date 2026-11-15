import type { Store } from "@prisma/client";
import { prisma } from "../db.js";
import {
  addDays,
  changeRatio,
  countOpenDays,
  missedDays,
  periodFromStart,
  previousPeriod,
  rankLines,
  weekdayName,
  type AnalysisPeriod,
  type DateRange,
  type ShareRow,
} from "./analytics.js";
import { resolveBusinessDate } from "./businessDate.js";
import { splitPayments, StoreQueries, type NotCountedInProfit } from "./tanyaQueries.js";
import { TRANSACTION_ROW_SELECT, toTransactionRow, type TransactionRow } from "./transactionRows.js";

// GET /home (Beranda, F4) and GET /analytics/* and /alerts (Analisis, F7), all
// computed on every request from the rows beneath them (spec §10: nothing
// stored, so a figure can never drift from its entries).

export type AlertJson = { id: string; rule: string; message: string };

export type HomeJson = {
  today: { date: string; masuk: number; keluar: number };
  comparisons: { label: string; masuk: number }[];
  // A card is null or empty when it has nothing to show (spec §6).
  cards: {
    alerts: AlertJson[];
    missedDays: string[];
    piutang: number | null;
    utang: number | null;
    dueToday: number | null;
    queuedReads: number | null;
  };
  entries: TransactionRow[];
};

export type SummaryJson = {
  masuk: number;
  keluar: number;
  untung: number;
  notCountedInProfit: NotCountedInProfit;
  change: { masuk: number | null; keluar: number | null; untung: number | null };
  daysRecorded: number;
  daysInPeriod: number;
  piutangAtEnd: number;
  utangAtEnd: number;
  editedEntryCount: number;
};

// Spec §6: "Belum dicatat" looks back a week.
const MISSED_DAYS_LOOKBACK = 7;
const MAX_HOME_ALERTS = 3;
const MAX_ALERTS = 20;

export async function getHome(storeId: string): Promise<HomeJson> {
  const { store, today, closedDays } = await loadStore(storeId);
  const queries = new StoreQueries(storeId, closedDays);
  const yesterday = addDays(today, -1);
  const sameDayLastWeek = addDays(today, -7);
  const [todayTotals, yesterdayTotals, lastWeekTotals] = await Promise.all(
    [today, yesterday, sameDayLastWeek].map(async (date) => splitPayments(await queries.paymentsIn({ from: date, to: date }))),
  );
  const [alerts, missed, piutang, utang, dueToday, queuedReads, entries] = await Promise.all([
    listAlerts(store, MAX_HOME_ALERTS),
    findMissedDays(store, today, closedDays),
    queries.openBalances("PIUTANG"),
    queries.openBalances("UTANG"),
    countDueToday(storeId, today),
    prisma.input.count({ where: { storeId, status: "QUEUED" } }),
    prisma.transaction.findMany({
      where: { storeId, deletedAt: null, businessDate: toDate(today) },
      select: TRANSACTION_ROW_SELECT,
      orderBy: { createdAt: "desc" },
    }),
  ]);
  return {
    today: { date: today, masuk: todayTotals?.masuk ?? 0, keluar: todayTotals?.keluar ?? 0 },
    comparisons: [
      { label: "Kemarin", masuk: yesterdayTotals?.masuk ?? 0 },
      { label: `${weekdayName(sameDayLastWeek)} lalu`, masuk: lastWeekTotals?.masuk ?? 0 },
    ],
    cards: {
      alerts,
      missedDays: missed,
      piutang: piutang.total > 0 ? piutang.total : null,
      utang: utang.total > 0 ? utang.total : null,
      dueToday: dueToday > 0 ? dueToday : null,
      queuedReads: queuedReads > 0 ? queuedReads : null,
    },
    entries: entries.map(toTransactionRow),
  };
}

export async function getSummary(storeId: string, period: AnalysisPeriod, start: string): Promise<SummaryJson> {
  const { today, closedDays } = await loadStore(storeId);
  const queries = new StoreQueries(storeId, closedDays);
  const range = periodFromStart(period, start, today);
  const [current, previous, daysRecorded, piutang, utang, editedEntryCount] = await Promise.all([
    queries.paymentsIn(range).then(splitPayments),
    queries.paymentsIn(previousPeriod(period, start)).then(splitPayments),
    queries.daysRecorded(range),
    queries.openBalances("PIUTANG", range.to),
    queries.openBalances("UTANG", range.to),
    prisma.transaction.count({ where: { storeId, deletedAt: null, businessDate: dateFilter(range), edits: { some: {} } } }),
  ]);
  const untung = current.masuk - current.keluar;
  return {
    masuk: current.masuk,
    keluar: current.keluar,
    // Spec §7.6: Analisis periods are a week or longer, so profit always shows.
    untung,
    notCountedInProfit: current.notCountedInProfit,
    change: {
      masuk: changeRatio(current.masuk, previous.masuk),
      keluar: changeRatio(current.keluar, previous.keluar),
      untung: changeRatio(untung, previous.masuk - previous.keluar),
    },
    daysRecorded,
    daysInPeriod: countOpenDays(range, closedDays),
    piutangAtEnd: piutang.total,
    utangAtEnd: utang.total,
    editedEntryCount,
  };
}

// Money in by item, or money out by category and expense item (spec §7.6).
export async function getRankedRows(
  storeId: string,
  options: { period: AnalysisPeriod; start: string; direction: "IN" | "OUT"; mode: "item" | "category" },
): Promise<ShareRow[]> {
  const { today } = await loadStore(storeId);
  const range = periodFromStart(options.period, options.start, today);
  const lines = await prisma.line.findMany({
    where: { transaction: { storeId, deletedAt: null, direction: options.direction, businessDate: dateFilter(range) } },
    select: {
      lineTotal: true,
      item: { select: { id: true, name: true } },
      category: { select: { id: true, name: true, countedInProfit: true } },
    },
  });
  return rankLines(
    lines.map((line) => ({
      lineTotal: line.lineTotal,
      countedInProfit: line.category?.countedInProfit ?? null,
      item: line.item,
      category: line.category === null ? null : { id: line.category.id, name: line.category.name },
    })),
    options.mode,
  );
}

export async function getAlerts(storeId: string): Promise<AlertJson[]> {
  const store = await prisma.store.findUniqueOrThrow({ where: { id: storeId } });
  return listAlerts(store, MAX_ALERTS);
}

// Alerts are written by the alert rules (S12). The Peringatan switch in
// Settings (F9) hides them all.
async function listAlerts(store: Store, limit: number): Promise<AlertJson[]> {
  if (!store.alertsOn) {
    return [];
  }
  const alerts = await prisma.alert.findMany({ where: { storeId: store.id, muted: false }, orderBy: { createdAt: "desc" }, take: limit });
  return alerts.map((alert) => ({ id: alert.id, rule: alert.rule, message: alert.value ?? alert.rule }));
}

// The last week's open days with no entry, never before the store existed.
async function findMissedDays(store: Store, today: string, closedDays: number[]): Promise<string[]> {
  const firstDay = resolveBusinessDate({ now: store.createdAt, timezone: store.timezone, dayChangeHour: store.dayChangeHour });
  const lookbackStart = addDays(today, -MISSED_DAYS_LOOKBACK);
  const range: DateRange = { from: lookbackStart > firstDay ? lookbackStart : firstDay, to: addDays(today, -1) };
  if (range.from > range.to) {
    return [];
  }
  const entries = await prisma.transaction.findMany({
    where: { storeId: store.id, deletedAt: null, businessDate: dateFilter(range) },
    select: { businessDate: true },
  });
  return missedDays(range, new Set(entries.map((entry) => entry.businessDate.toISOString().slice(0, 10))), closedDays);
}

// Spec §7.4: Piutang and Utang due today that are not fully paid.
async function countDueToday(storeId: string, today: string): Promise<number> {
  const due = await prisma.transaction.findMany({
    where: { storeId, deletedAt: null, dueDate: toDate(today) },
    select: { total: true, payments: { select: { amount: true } } },
  });
  return due.filter((transaction) => transaction.total > transaction.payments.reduce((sum, payment) => sum + payment.amount, 0)).length;
}

async function loadStore(storeId: string): Promise<{ store: Store; today: string; closedDays: number[] }> {
  const store = await prisma.store.findUniqueOrThrow({ where: { id: storeId } });
  const today = resolveBusinessDate({ now: new Date(), timezone: store.timezone, dayChangeHour: store.dayChangeHour });
  const closedDays = Array.isArray(store.closedDays) ? store.closedDays.filter((day): day is number => typeof day === "number") : [];
  return { store, today, closedDays };
}

function dateFilter(range: DateRange): { gte: Date; lte: Date } {
  return { gte: toDate(range.from), lte: toDate(range.to) };
}

function toDate(date: string): Date {
  return new Date(`${date}T00:00:00Z`);
}
