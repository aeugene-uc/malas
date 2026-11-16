import type { Store } from "@prisma/client";
import { prisma } from "../db.js";
import { ApiError } from "../errors.js";
import * as alertRules from "./alertRules.js";
import { addDays } from "./analytics.js";
import { resolveBusinessDate } from "./businessDate.js";

// Spec §12: alerts run when the app opens, since phones kill background jobs.
// Beranda and the alert list call this before reading, and the rules write any
// new Alert rows. The §7.7 guards keep a repeat open from adding more.

// The repeat guard looks back 7 business days; one more calendar day covers
// the day-change hour.
const LOOKBACK_DAYS = 8;

export async function refreshAlerts(store: Store, today: string): Promise<void> {
  if (!store.alertsOn) {
    return;
  }
  const [purchases, dueEntries, recentAlerts, mutedItemIds] = await Promise.all([
    loadRecentPurchases(store.id, today),
    loadDueToday(store.id, today),
    loadRecentAlerts(store),
    loadMutedItemIds(store.id),
  ]);
  const candidates = [...alertRules.findPriceRises(purchases, today), ...alertRules.findDueToday(dueEntries)];
  const picked = alertRules.pickAlertsToRaise({ candidates, recentAlerts, mutedItemIds, today });
  // Alerts are listed newest first, so the largest is written last.
  const now = Date.now();
  await prisma.alert.createMany({
    data: [...picked].reverse().map((alert, index) => ({
      storeId: store.id,
      rule: alert.rule,
      itemId: alert.itemId,
      entryId: alert.entryId,
      value: alert.message,
      createdAt: new Date(now + index),
    })),
  });
}

// Every purchase of an item with a quantity and unit, since a rise compares the
// latest one with whichever came before it, however long ago.
async function loadRecentPurchases(storeId: string, today: string): Promise<alertRules.PurchaseLine[]> {
  const itemsBoughtThisWeek = await prisma.line.findMany({
    where: { transaction: { storeId, deletedAt: null, direction: "OUT", businessDate: { gte: toDate(addDays(today, -6)) } }, item: { kind: "BOUGHT" } },
    select: { itemId: true },
    distinct: ["itemId"],
  });
  const itemIds = itemsBoughtThisWeek.map((line) => line.itemId).filter((id): id is string => id !== null);
  if (itemIds.length === 0) {
    return [];
  }
  const lines = await prisma.line.findMany({
    where: { itemId: { in: itemIds }, quantity: { not: null }, unit: { not: null }, transaction: { storeId, deletedAt: null, direction: "OUT" } },
    select: {
      lineTotal: true,
      quantity: true,
      unit: true,
      item: { select: { id: true, name: true } },
      transaction: { select: { id: true, businessDate: true, createdAt: true } },
    },
  });
  return lines.flatMap((line) =>
    line.item === null || line.quantity === null || line.unit === null
      ? []
      : [
          {
            transactionId: line.transaction.id,
            businessDate: line.transaction.businessDate.toISOString().slice(0, 10),
            createdAt: line.transaction.createdAt,
            itemId: line.item.id,
            itemName: line.item.name,
            unit: line.unit,
            quantity: line.quantity.toString(),
            lineTotal: line.lineTotal,
          },
        ],
  );
}

async function loadDueToday(storeId: string, today: string): Promise<alertRules.DueEntry[]> {
  const due = await prisma.transaction.findMany({
    where: { storeId, deletedAt: null, dueDate: toDate(today) },
    select: { id: true, direction: true, total: true, person: { select: { name: true } }, payments: { select: { amount: true } } },
  });
  return due.map((transaction) => ({
    transactionId: transaction.id,
    direction: transaction.direction,
    remaining: transaction.total - transaction.payments.reduce((sum, payment) => sum + payment.amount, 0),
    personName: transaction.person?.name ?? null,
  }));
}

async function loadRecentAlerts(store: Store): Promise<alertRules.RecentAlert[]> {
  const since = new Date(Date.now() - LOOKBACK_DAYS * 24 * 60 * 60 * 1000);
  const alerts = await prisma.alert.findMany({
    where: { storeId: store.id, createdAt: { gte: since } },
    select: { rule: true, itemId: true, entryId: true, createdAt: true },
  });
  return alerts.map((alert) => ({
    rule: alert.rule,
    itemId: alert.itemId,
    entryId: alert.entryId,
    businessDate: resolveBusinessDate({ now: alert.createdAt, timezone: store.timezone, dayChangeHour: store.dayChangeHour }),
  }));
}

// "Jangan ingatkan" mutes one alert, and with it every later alert on its item.
async function loadMutedItemIds(storeId: string): Promise<Set<string>> {
  const muted = await prisma.alert.findMany({ where: { storeId, muted: true, itemId: { not: null } }, select: { itemId: true }, distinct: ["itemId"] });
  return new Set(muted.map((alert) => alert.itemId).filter((id): id is string => id !== null));
}

function toDate(date: string): Date {
  return new Date(`${date}T00:00:00Z`);
}

export type AlertChanges = Partial<{ seen: boolean; muted: boolean }>;
export type AlertJson = { id: string; rule: string; message: string | null; seen: boolean; muted: boolean };

// "Jangan ingatkan" (§7.7) mutes the alert, and loadMutedItemIds then keeps
// every later alert on its item from being raised. Seen marks it read.
export async function updateAlert(options: { storeId: string; alertId: string; changes: AlertChanges }): Promise<AlertJson> {
  const { count } = await prisma.alert.updateMany({ where: { id: options.alertId, storeId: options.storeId }, data: options.changes });
  if (count === 0) {
    throw new ApiError({ code: "NOT_FOUND", message: "Peringatan tidak ditemukan" });
  }
  const alert = await prisma.alert.findUniqueOrThrow({ where: { id: options.alertId } });
  return { id: alert.id, rule: alert.rule, message: alert.value, seen: alert.seen, muted: alert.muted };
}
