import { prisma } from "../db.js";
import { normaliseName } from "./normaliseName.js";
import type { OpenBalances, PeriodRange, RankOptions, Ranked, RankedRow, TanyaQueries, Totals } from "./tanya.js";

// The 4 queries Tanya runs (spec §7.8), computed in code by spec §10's rules.
// Analisis (S7) uses the same rules and can build on these.
//
// - Masuk and Keluar count payments on their payment date, only in categories
//   counted in profit. A line with no category counts, like a plain sale.
// - Item and category figures count line totals on the transaction's date.
// - Days recorded are days with at least one entry, closed days left out.
// - Piutang is what customers still owe; Utang what the owner still owes, plus
//   any overpayment the owner must give back (Kembalikan).

export class StoreQueries implements TanyaQueries {
  constructor(
    private readonly storeId: string,
    // ISO weekdays, 1 is Monday.
    private readonly closedDays: number[],
  ) {}

  async totals(range: PeriodRange): Promise<Totals> {
    const payments = await prisma.payment.findMany({
      where: { date: { gte: toDate(range.from), lte: toDate(range.to) }, transaction: { storeId: this.storeId, deletedAt: null } },
      select: { amount: true, transaction: { select: { direction: true, lines: { select: { category: { select: { countedInProfit: true } } } } } } },
    });
    let masuk = 0;
    let keluar = 0;
    for (const payment of payments) {
      if (!isCountedInProfit(payment.transaction.lines.map((line) => line.category?.countedInProfit ?? null))) {
        continue;
      }
      if (payment.transaction.direction === "IN") {
        masuk += payment.amount;
      } else {
        keluar += payment.amount;
      }
    }
    return { masuk, keluar, daysRecorded: await this.daysRecorded(range) };
  }

  async byItem(options: RankOptions): Promise<Ranked> {
    const lines = await this.linesIn(options);
    const rows = lines
      .filter((line) => line.item !== null)
      .filter((line) => options.name === null || (line.item?.normalisedName ?? "").includes(normaliseName(options.name)))
      .map((line) => ({ label: line.item?.name ?? "", amount: line.lineTotal, quantity: line.quantity?.toString() ?? null, unit: line.item?.unit ?? line.unit }));
    return { rows: rankRows(rows, options.limit), daysRecorded: await this.daysRecorded(options.range) };
  }

  // A name may be a category ("bensin" as Operasional's own) or an item bought
  // in any category, so both are searched.
  async byCategory(options: RankOptions): Promise<Ranked> {
    const lines = await this.linesIn(options);
    const wanted = options.name === null ? null : normaliseName(options.name);
    const rows: RankInput[] = [];
    for (const line of lines) {
      const categoryName = line.category?.name ?? "Tanpa kategori";
      const isCategoryMatch = wanted === null || normaliseName(categoryName).includes(wanted);
      const isItemMatch = wanted !== null && (line.item?.normalisedName ?? "").includes(wanted);
      if (isCategoryMatch) {
        rows.push({ label: categoryName, amount: line.lineTotal, quantity: null, unit: null });
      } else if (isItemMatch) {
        rows.push({ label: line.item?.name ?? categoryName, amount: line.lineTotal, quantity: null, unit: null });
      }
    }
    return { rows: rankRows(rows, options.limit), daysRecorded: await this.daysRecorded(options.range) };
  }

  async openBalances(kind: "PIUTANG" | "UTANG"): Promise<OpenBalances> {
    const transactions = await prisma.transaction.findMany({
      where: { storeId: this.storeId, deletedAt: null },
      select: { direction: true, total: true, person: { select: { name: true } }, payments: { select: { amount: true } } },
    });
    return sumOpenBalances(
      transactions.map((transaction) => ({
        direction: transaction.direction,
        total: transaction.total,
        paid: transaction.payments.reduce((sum, payment) => sum + payment.amount, 0),
        personName: transaction.person?.name ?? null,
      })),
      kind,
    );
  }

  private async linesIn(options: RankOptions) {
    return prisma.line.findMany({
      where: {
        transaction: {
          storeId: this.storeId,
          deletedAt: null,
          direction: options.direction,
          businessDate: { gte: toDate(options.range.from), lte: toDate(options.range.to) },
        },
      },
      select: {
        lineTotal: true,
        quantity: true,
        unit: true,
        item: { select: { name: true, normalisedName: true, unit: true } },
        category: { select: { name: true } },
      },
    });
  }

  private async daysRecorded(range: PeriodRange): Promise<number> {
    const entries = await prisma.transaction.findMany({
      where: { storeId: this.storeId, deletedAt: null, businessDate: { gte: toDate(range.from), lte: toDate(range.to) } },
      select: { businessDate: true },
    });
    return countDaysRecorded(
      entries.map((entry) => entry.businessDate),
      this.closedDays,
    );
  }
}

// ---- Pure rules, tested without a database ----------------------------------

// A transaction counts in profit unless all its lines sit in categories that do
// not (Modal masuk, Pinjaman masuk, ...). null is a line with no category.
export function isCountedInProfit(lineCategoryFlags: (boolean | null)[]): boolean {
  return lineCategoryFlags.length === 0 || lineCategoryFlags.some((flag) => flag !== false);
}

export function countDaysRecorded(businessDates: Date[], closedDays: number[]): number {
  const openDays = new Set<string>();
  for (const date of businessDates) {
    const isoWeekday = date.getUTCDay() === 0 ? 7 : date.getUTCDay();
    if (!closedDays.includes(isoWeekday)) {
      openDays.add(date.toISOString().slice(0, 10));
    }
  }
  return openDays.size;
}

export type RankInput = { label: string; amount: number; quantity: string | null; unit: string | null };

// Adds up lines with the same label, largest amount first. Quantities add in
// thousandths so "0.5" + "0.25" stays exact.
export function rankRows(rows: RankInput[], limit: number): RankedRow[] {
  const totalsByLabel = new Map<string, { amount: number; thousandths: number | null; unit: string | null }>();
  for (const row of rows) {
    const total = totalsByLabel.get(row.label) ?? { amount: 0, thousandths: null, unit: row.unit };
    total.amount += row.amount;
    if (row.quantity !== null) {
      total.thousandths = (total.thousandths ?? 0) + toThousandths(row.quantity);
    }
    totalsByLabel.set(row.label, total);
  }
  return [...totalsByLabel.entries()]
    .map(([name, total]) => ({ name, amount: total.amount, quantity: total.thousandths === null ? null : formatThousandths(total.thousandths), unit: total.unit }))
    .sort((a, b) => b.amount - a.amount)
    .slice(0, limit);
}

export type BalanceInput = { direction: "IN" | "OUT"; total: number; paid: number; personName: string | null };

export function sumOpenBalances(transactions: BalanceInput[], kind: "PIUTANG" | "UTANG"): OpenBalances {
  const remainingByPerson = new Map<string | null, number>();
  for (const transaction of transactions) {
    const remaining = transaction.total - transaction.paid;
    const isPiutang = transaction.direction === "IN" && remaining > 0;
    // Money out not yet paid, or money in paid beyond its total (Kembalikan).
    const owedByOwner = transaction.direction === "OUT" ? Math.max(0, remaining) : Math.max(0, -remaining);
    const amount = kind === "PIUTANG" ? (isPiutang ? remaining : 0) : owedByOwner;
    if (amount > 0) {
      remainingByPerson.set(transaction.personName, (remainingByPerson.get(transaction.personName) ?? 0) + amount);
    }
  }
  const rows = [...remainingByPerson.entries()].map(([personName, remaining]) => ({ personName, remaining })).sort((a, b) => b.remaining - a.remaining);
  return { rows, total: rows.reduce((sum, row) => sum + row.remaining, 0) };
}

function toDate(isoDate: string): Date {
  return new Date(`${isoDate}T00:00:00Z`);
}

function toThousandths(quantity: string): number {
  const negative = quantity.startsWith("-");
  const [whole = "0", fraction = ""] = quantity.replace("-", "").split(".");
  const value = Number(whole) * 1000 + Number(fraction.padEnd(3, "0").slice(0, 3));
  return negative ? -value : value;
}

function formatThousandths(value: number): string {
  const sign = value < 0 ? "-" : "";
  const absolute = Math.abs(value);
  const fraction = String(absolute % 1000).padStart(3, "0").replace(/0+$/, "");
  const whole = Math.trunc(absolute / 1000);
  return fraction === "" ? `${sign}${whole}` : `${sign}${whole}.${fraction}`;
}
