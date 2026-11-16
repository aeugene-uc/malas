import type { Prisma } from "@prisma/client";

// A transaction as a list row (contract rev 3, #66): what Beranda's entries and
// Catatan's list show without a second call per row. remaining goes negative
// when the owner was paid more than the total (Kembalikan).

export const TRANSACTION_ROW_SELECT = {
  id: true,
  businessDate: true,
  direction: true,
  total: true,
  dueDate: true,
  person: { select: { id: true, name: true } },
  payments: { select: { amount: true } },
  lines: {
    select: {
      id: true,
      quantity: true,
      unit: true,
      unitPrice: true,
      lineTotal: true,
      discount: true,
      item: { select: { id: true, name: true } },
      category: { select: { id: true, name: true } },
    },
  },
  // Loans link transactions too, so only a linked entry with a negative
  // quantity is a retur (spec §4.2).
  _count: { select: { edits: true, linkedBy: { where: { lines: { some: { quantity: { lt: 0 } } } } } } },
} satisfies Prisma.TransactionSelect;

type TransactionForRow = Prisma.TransactionGetPayload<{ select: typeof TRANSACTION_ROW_SELECT }>;

export type TransactionRow = {
  id: string;
  businessDate: string;
  direction: "IN" | "OUT";
  total: number;
  dueDate: string | null;
  paid: number;
  remaining: number;
  editCount: number;
  hasRetur: boolean;
  person: { id: string; name: string } | null;
  lines: {
    id: string;
    item: { id: string; name: string } | null;
    category: { id: string; name: string } | null;
    quantity: string | null;
    unit: string | null;
    unitPrice: number | null;
    lineTotal: number;
    discount: number;
  }[];
};

export function toTransactionRow(transaction: TransactionForRow): TransactionRow {
  const paid = transaction.payments.reduce((sum, payment) => sum + payment.amount, 0);
  return {
    id: transaction.id,
    businessDate: transaction.businessDate.toISOString().slice(0, 10),
    direction: transaction.direction,
    total: transaction.total,
    dueDate: transaction.dueDate?.toISOString().slice(0, 10) ?? null,
    paid,
    remaining: transaction.total - paid,
    editCount: transaction._count.edits,
    hasRetur: transaction._count.linkedBy > 0,
    person: transaction.person,
    lines: transaction.lines.map((line) => ({
      id: line.id,
      item: line.item,
      category: line.category,
      quantity: line.quantity?.toString() ?? null,
      unit: line.unit,
      unitPrice: line.unitPrice,
      lineTotal: line.lineTotal,
      discount: line.discount,
    })),
  };
}
