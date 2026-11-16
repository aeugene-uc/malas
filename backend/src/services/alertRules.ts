import { addDays } from "./analytics.js";

// Spec §7.7 alert rules and guards, pure and filled from fixed templates, so
// they work offline and on the free plan. Only price rise and due today are
// built: the 28-day and 12-month rules cannot fire during a 14-day test (#80).
// The guard on items under Rp 100.000 or 5 entries belongs to those window
// rules; applied to a price rise it would stop it firing "from the second
// purchase".

export type AlertRule = "PRICE_RISE" | "DUE_TODAY";

export type PurchaseLine = {
  transactionId: string;
  businessDate: string;
  // Orders two purchases of one item on the same day.
  createdAt: Date;
  itemId: string;
  itemName: string;
  unit: string;
  quantity: string;
  lineTotal: number;
};

export type DueEntry = { transactionId: string; direction: "IN" | "OUT"; remaining: number; personName: string | null };

// size is the rupiah the alert is about, for "largest first".
export type AlertCandidate = { rule: AlertRule; itemId: string | null; entryId: string; message: string; size: number };

export type RecentAlert = { rule: string; itemId: string | null; entryId: string | null; businessDate: string };

// The latest unit price must be at least 110% of the one before.
const PRICE_RISE_PERCENT = 10;
const MAX_ALERTS_PER_DAY = 3;
const NO_REPEAT_DAYS = 7;

// A purchase raises an alert in the week it was recorded, not on the first app
// open after an old rise.
export function findPriceRises(purchases: PurchaseLine[], today: string): AlertCandidate[] {
  const purchasesByItemAndUnit = new Map<string, PurchaseLine[]>();
  for (const purchase of purchases) {
    if (toThousandths(purchase.quantity) <= 0) {
      continue;
    }
    const key = `${purchase.itemId}|${purchase.unit}`;
    purchasesByItemAndUnit.set(key, [...(purchasesByItemAndUnit.get(key) ?? []), purchase]);
  }
  const firstDayOfWindow = addDays(today, -(NO_REPEAT_DAYS - 1));
  const candidates: AlertCandidate[] = [];
  for (const itemPurchases of purchasesByItemAndUnit.values()) {
    const [previous, latest] = itemPurchases.sort(byWhenBought).slice(-2);
    if (previous === undefined || latest === undefined || latest.businessDate < firstDayOfWindow) {
      continue;
    }
    const previousPrice = computeUnitPrice(previous);
    const latestPrice = computeUnitPrice(latest);
    const isRise = previousPrice > 0 && latestPrice * 100 >= previousPrice * (100 + PRICE_RISE_PERCENT);
    if (!isRise) {
      continue;
    }
    const risePercent = Math.round(((latestPrice - previousPrice) * 100) / previousPrice);
    candidates.push({
      rule: "PRICE_RISE",
      itemId: latest.itemId,
      entryId: latest.transactionId,
      message: `Harga ${latest.itemName} naik ${risePercent}%: ${formatRupiah(previousPrice)} → ${formatRupiah(latestPrice)} per ${latest.unit}`,
      size: Math.round(((latestPrice - previousPrice) * toThousandths(latest.quantity)) / 1000),
    });
  }
  return candidates;
}

export function findDueToday(entries: DueEntry[]): AlertCandidate[] {
  return entries
    .filter((entry) => entry.remaining > 0)
    .map((entry): AlertCandidate => {
      const amount = formatRupiah(entry.remaining);
      const balance = entry.direction === "IN" ? `Piutang${withName(entry.personName)}` : `Utang${withName(entry.personName, "ke")}`;
      return { rule: "DUE_TODAY", itemId: null, entryId: entry.transactionId, message: `${balance} ${amount} jatuh tempo hari ini`, size: entry.remaining };
    });
}

// Spec §7.7 guards: a muted item stays quiet, the same alert does not come back
// within 7 days, and at most 3 are raised a day, largest first.
export function pickAlertsToRaise(options: {
  candidates: AlertCandidate[];
  recentAlerts: RecentAlert[];
  mutedItemIds: Set<string>;
  today: string;
}): AlertCandidate[] {
  const firstDayOfWindow = addDays(options.today, -(NO_REPEAT_DAYS - 1));
  const recentInWindow = options.recentAlerts.filter((alert) => alert.businessDate >= firstDayOfWindow);
  const recentKeys = new Set(recentInWindow.map((alert) => repeatKey(alert)));
  const raisedToday = recentInWindow.filter((alert) => alert.businessDate === options.today).length;
  return options.candidates
    .filter((candidate) => candidate.itemId === null || !options.mutedItemIds.has(candidate.itemId))
    .filter((candidate) => !recentKeys.has(repeatKey(candidate)))
    .sort((a, b) => b.size - a.size)
    .slice(0, Math.max(0, MAX_ALERTS_PER_DAY - raisedToday));
}

// "Rp 12.500" (spec §5.8).
export function formatRupiah(amount: number): string {
  return `Rp ${String(amount).replace(/\B(?=(\d{3})+(?!\d))/g, ".")}`;
}

// A price rise repeats per item, a due date per entry.
function repeatKey(alert: { rule: string; itemId: string | null; entryId: string | null }): string {
  return alert.rule === "PRICE_RISE" ? `${alert.rule}|${alert.itemId}` : `${alert.rule}|${alert.entryId}`;
}

function byWhenBought(a: PurchaseLine, b: PurchaseLine): number {
  return a.businessDate === b.businessDate ? a.createdAt.getTime() - b.createdAt.getTime() : a.businessDate < b.businessDate ? -1 : 1;
}

// Spec §10: unit price = line total / quantity, in whole rupiah.
function computeUnitPrice(purchase: PurchaseLine): number {
  return Math.round((purchase.lineTotal * 1000) / toThousandths(purchase.quantity));
}

function withName(personName: string | null, preposition?: string): string {
  if (personName === null) {
    return "";
  }
  return preposition === undefined ? ` ${personName}` : ` ${preposition} ${personName}`;
}

function toThousandths(quantity: string): number {
  const isNegative = quantity.startsWith("-");
  const [whole = "0", fraction = ""] = quantity.replace("-", "").split(".");
  const value = Number(whole) * 1000 + Number(fraction.padEnd(3, "0").slice(0, 3));
  return isNegative ? -value : value;
}
