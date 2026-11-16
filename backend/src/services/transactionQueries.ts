import type { Prisma } from "@prisma/client";
import { prisma } from "../db.js";
import { ApiError } from "../errors.js";
import { TRANSACTION_ROW_SELECT, toTransactionRow, type TransactionRow } from "./transactionRows.js";

// Catatan's reads (spec §6, §7.4, §7.5): the list with its filters, one entry
// with its payments, its edit history, and the Piutang and Utang lists. Rows
// are the same shape /home sends, so the app has one reader for all of them.

export type ListFilter = {
  from: string | null;
  to: string | null;
  direction: "IN" | "OUT" | null;
  itemId: string | null;
  categoryId: string | null;
  personId: string | null;
  isUnpaidOnly: boolean;
  q: string | null;
  cursor: string | null;
};

const PAGE_SIZE = 30;
// Newest first, and stable within a day.
const NEWEST_FIRST: Prisma.TransactionOrderByWithRelationInput[] = [{ businessDate: "desc" }, { createdAt: "desc" }, { id: "desc" }];

export async function list(storeId: string, filter: ListFilter): Promise<{ transactions: TransactionRow[]; nextCursor: string | null }> {
  const where = buildWhere(storeId, filter);
  // "Belum lunas" depends on payments, which SQL here cannot compare to the
  // total, so that filter pages over the matching rows in code. A micro
  // business has hundreds of entries, not millions.
  if (filter.isUnpaidOnly) {
    const rows = (await prisma.transaction.findMany({ where, orderBy: NEWEST_FIRST, select: TRANSACTION_ROW_SELECT })).map(toTransactionRow).filter((row) => row.remaining > 0);
    const start = filter.cursor === null ? 0 : rows.findIndex((row) => row.id === filter.cursor) + 1;
    const page = rows.slice(start, start + PAGE_SIZE);
    return { transactions: page, nextCursor: start + PAGE_SIZE < rows.length ? (page.at(-1)?.id ?? null) : null };
  }
  const found = await prisma.transaction.findMany({
    where,
    orderBy: NEWEST_FIRST,
    select: TRANSACTION_ROW_SELECT,
    take: PAGE_SIZE + 1,
    ...(filter.cursor === null ? {} : { cursor: { id: filter.cursor }, skip: 1 }),
  });
  const page = found.slice(0, PAGE_SIZE).map(toTransactionRow);
  return { transactions: page, nextCursor: found.length > PAGE_SIZE ? (page.at(-1)?.id ?? null) : null };
}

function buildWhere(storeId: string, filter: ListFilter): Prisma.TransactionWhereInput {
  const lineFilters: Prisma.LineWhereInput[] = [];
  if (filter.itemId !== null) lineFilters.push({ itemId: filter.itemId });
  if (filter.categoryId !== null) lineFilters.push({ categoryId: filter.categoryId });
  const dateRange = { ...(filter.from === null ? {} : { gte: toDbDate(filter.from) }), ...(filter.to === null ? {} : { lte: toDbDate(filter.to) }) };
  return {
    storeId,
    deletedAt: null,
    ...(Object.keys(dateRange).length === 0 ? {} : { businessDate: dateRange }),
    ...(filter.direction === null ? {} : { direction: filter.direction }),
    ...(filter.personId === null ? {} : { personId: filter.personId }),
    AND: [
      ...lineFilters.map((lineFilter) => ({ lines: { some: lineFilter } })),
      // The database collation ignores case, so "budi" finds "Pak Budi".
      ...(filter.q === null
        ? []
        : [{ OR: [{ person: { name: { contains: filter.q } } }, { lines: { some: { OR: [{ item: { name: { contains: filter.q } } }, { category: { name: { contains: filter.q } } }] } } }, { note: { contains: filter.q } }] }]),
    ],
  };
}

export type TransactionDetail = TransactionRow & {
  note: string | null;
  source: string;
  linkedTransactionId: string | null;
  payments: { id: string; date: string; amount: number; label: string | null }[];
};

export async function getDetail(storeId: string, transactionId: string): Promise<TransactionDetail> {
  const transaction = await prisma.transaction.findFirst({
    where: { id: transactionId, storeId, deletedAt: null },
    select: { ...TRANSACTION_ROW_SELECT, note: true, source: true, linkedTransactionId: true, payments: { select: { id: true, date: true, amount: true, label: true }, orderBy: { date: "asc" } } },
  });
  if (transaction === null) {
    throw new ApiError({ code: "NOT_FOUND", message: "Catatan tidak ditemukan" });
  }
  return {
    ...toTransactionRow(transaction),
    note: transaction.note,
    source: transaction.source,
    linkedTransactionId: transaction.linkedTransactionId,
    payments: transaction.payments.map((payment) => ({ id: payment.id, date: toIsoDate(payment.date), amount: payment.amount, label: payment.label })),
  };
}

// §7.5: "Diubah 2x" and its history on tap, newest first.
export async function getHistory(storeId: string, transactionId: string): Promise<{ id: string; at: string; previous: Prisma.JsonValue }[]> {
  const transaction = await prisma.transaction.findFirst({ where: { id: transactionId, storeId }, select: { edits: { orderBy: { at: "desc" } } } });
  if (transaction === null) {
    throw new ApiError({ code: "NOT_FOUND", message: "Catatan tidak ditemukan" });
  }
  return transaction.edits.map((editRow) => ({ id: editRow.id, at: editRow.at.toISOString(), previous: editRow.previous }));
}

export type OpenKind = "PIUTANG" | "UTANG";

// §7.4, one row per transaction however many lines (§4.1). Piutang: money in
// not fully paid. Utang: money out not fully paid, plus money in paid beyond
// its total (Kembalikan), the same split as sumOpenBalances in Tanya. Rows with
// a due date come first, soonest first.
export async function listOpen(storeId: string, kind: OpenKind): Promise<TransactionRow[]> {
  const rows = (await prisma.transaction.findMany({ where: { storeId, deletedAt: null }, orderBy: NEWEST_FIRST, select: TRANSACTION_ROW_SELECT })).map(toTransactionRow);
  return rows.filter((row) => isOpenAs(row, kind)).sort(byDueDateThenNewest);
}

export function isOpenAs(row: { direction: "IN" | "OUT"; remaining: number }, kind: OpenKind): boolean {
  if (kind === "PIUTANG") {
    return row.direction === "IN" && row.remaining > 0;
  }
  return row.direction === "OUT" ? row.remaining > 0 : row.remaining < 0;
}

function byDueDateThenNewest(first: TransactionRow, second: TransactionRow): number {
  if (first.dueDate === second.dueDate) return 0;
  if (first.dueDate === null) return 1;
  if (second.dueDate === null) return -1;
  return first.dueDate < second.dueDate ? -1 : 1;
}

function toDbDate(date: string): Date {
  return new Date(`${date}T00:00:00Z`);
}

function toIsoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}
