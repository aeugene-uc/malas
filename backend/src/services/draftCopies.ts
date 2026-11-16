import { prisma } from "../db.js";
import { ApiError } from "../errors.js";
import { resolveBusinessDate } from "./businessDate.js";

// Ulangi and Retur (spec §7.5) open the draft screen with a copy of an entry.
// Nothing is saved until Simpan, so these only read. The reply has the shape of
// /ai/read, {drafts, warnings}, so the app opens it the same way (#281).

export type CopyLine = {
  itemId: string | null;
  itemName: string | null;
  categoryId: string | null;
  categoryHint: null;
  quantity: string | null;
  unit: string | null;
  unitPrice: number | null;
  lineTotal: number | null;
};

export type CopyDraft = {
  businessDate: string;
  direction: "IN" | "OUT";
  total: number;
  personId: string | null;
  personName: string | null;
  dueDate: null;
  source: "TYPED";
  inputId: null;
  note: null;
  linkedTransactionId: string | null;
  lines: CopyLine[];
  payments: { date: string; amount: number; label: string | null }[];
};

export type SourceEntry = {
  id: string;
  direction: "IN" | "OUT";
  total: number;
  person: { id: string; name: string } | null;
  paid: number;
  lines: { itemId: string | null; itemName: string | null; categoryId: string | null; quantity: string | null; unit: string | null; unitPrice: number | null; lineTotal: number }[];
};

export async function buildDraftFor(options: { storeId: string; transactionId: string; kind: "REPEAT" | "RETUR" }): Promise<{ drafts: CopyDraft[]; warnings: never[] }> {
  const entry = await readSourceEntry(options.storeId, options.transactionId);
  const store = await prisma.store.findUniqueOrThrow({ where: { id: options.storeId } });
  const today = resolveBusinessDate({ now: new Date(), timezone: store.timezone, dayChangeHour: store.dayChangeHour });
  const draft = options.kind === "REPEAT" ? buildRepeatDraft(entry, today) : buildReturDraft(entry, today);
  return { drafts: [draft], warnings: [] };
}

// Ulangi copies an entry to today (ice, gas), at the price it had. A copy of
// an entry paid in full is paid in full today; a bon stays a bon.
export function buildRepeatDraft(entry: SourceEntry, today: string): CopyDraft {
  const isPaidInFull = entry.paid >= entry.total;
  return {
    ...startDraft(entry, today),
    total: entry.total,
    linkedTransactionId: null,
    lines: entry.lines.map((line) => toCopyLine(line, { quantity: line.quantity, lineTotal: line.lineTotal })),
    payments: isPaidInFull ? [{ date: today, amount: entry.total, label: "cash" }] : [],
  };
}

// Retur opens the original's lines at negative quantities, dated today and
// linked to the original. The owner sets the quantity; the server works out
// the money on Simpan, so the draft carries no payment.
export function buildReturDraft(entry: SourceEntry, today: string): CopyDraft {
  // The whole line back by default, at what was charged: a discounted sale
  // refunds the discounted amount.
  const lines = entry.lines.map((line) => toCopyLine(line, { quantity: line.quantity === null ? null : negate(line.quantity), lineTotal: -line.lineTotal }));
  return { ...startDraft(entry, today), total: lines.reduce((sum, line) => sum + (line.lineTotal ?? 0), 0), linkedTransactionId: entry.id, lines, payments: [] };
}

function startDraft(entry: SourceEntry, today: string): Omit<CopyDraft, "total" | "linkedTransactionId" | "lines" | "payments"> {
  return { businessDate: today, direction: entry.direction, personId: entry.person?.id ?? null, personName: entry.person?.name ?? null, dueDate: null, source: "TYPED", inputId: null, note: null };
}

function toCopyLine(line: SourceEntry["lines"][number], money: { quantity: string | null; lineTotal: number | null }): CopyLine {
  return { itemId: line.itemId, itemName: line.itemName, categoryId: line.categoryId, categoryHint: null, quantity: money.quantity, unit: line.unit, unitPrice: line.unitPrice, lineTotal: money.lineTotal };
}

function negate(quantity: string): string {
  return quantity.startsWith("-") ? quantity.slice(1) : `-${quantity}`;
}

async function readSourceEntry(storeId: string, transactionId: string): Promise<SourceEntry> {
  const transaction = await prisma.transaction.findFirst({
    where: { id: transactionId, storeId, deletedAt: null },
    select: {
      id: true,
      direction: true,
      total: true,
      person: { select: { id: true, name: true } },
      payments: { select: { amount: true } },
      lines: { select: { itemId: true, item: { select: { name: true } }, categoryId: true, quantity: true, unit: true, unitPrice: true, lineTotal: true } },
    },
  });
  if (transaction === null) {
    throw new ApiError({ code: "NOT_FOUND", message: "Catatan tidak ditemukan" });
  }
  return {
    id: transaction.id,
    direction: transaction.direction,
    total: transaction.total,
    person: transaction.person,
    paid: transaction.payments.reduce((sum, payment) => sum + payment.amount, 0),
    lines: transaction.lines.map((line) => ({
      itemId: line.itemId,
      itemName: line.item?.name ?? null,
      categoryId: line.categoryId,
      quantity: line.quantity?.toString() ?? null,
      unit: line.unit,
      unitPrice: line.unitPrice,
      lineTotal: line.lineTotal,
    })),
  };
}
