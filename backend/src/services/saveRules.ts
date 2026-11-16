// Simpan's arithmetic (spec §7.3, §10), with no database so every rule is
// tested offline. The client's numbers are never trusted (§5.1): code recomputes
// every line and the transaction from what the owner said or saw.

// Quantities carry up to 3 decimals ("setengah kilo" is 0.5), so they are
// counted in thousandths to keep every product an exact integer.
const MILLI = 1000;

export type PricedLine = { quantity: string | null; unitPrice: number | null; lineTotal: number | null };
export type LineMoney = { unitPrice: number | null; lineTotal: number; discount: number; hasNoPrice: boolean };

// §10: line total = the spoken or printed total when given, otherwise
// quantity x unit price. discount = quantity x unit price - line total.
// A line with no total and no way to compute one saves at 0, flagged (§5.4).
export function computeLineMoney(line: PricedLine, savedPrice: number | null): LineMoney {
  // §7.3: code fills prices from saved items.
  const unitPrice = line.unitPrice ?? (line.lineTotal === null ? savedPrice : null);
  const computedTotal = line.quantity === null || unitPrice === null ? null : multiplyQuantity(line.quantity, unitPrice);
  if (line.lineTotal !== null) {
    return { unitPrice, lineTotal: line.lineTotal, discount: computedTotal === null ? 0 : computedTotal - line.lineTotal, hasNoPrice: false };
  }
  if (computedTotal !== null) {
    return { unitPrice, lineTotal: computedTotal, discount: 0, hasNoPrice: false };
  }
  return { unitPrice, lineTotal: 0, discount: 0, hasNoPrice: true };
}

// Rounded to whole rupiah, because 0.333 kg at Rp 14.000 is not a whole number.
export function multiplyQuantity(quantity: string, unitPrice: number): number {
  return Math.round((toMilli(quantity) * unitPrice) / MILLI);
}

export function toMilli(quantity: string): number {
  return Math.round(Number(quantity) * MILLI);
}

export type GapLine = { lineTotal: number; discount: number };

// §10 and the contract: a spoken or printed transaction total wins over the sum
// of its lines. A total below the lines is a discount, taken from the last lines
// first without taking any line below zero. A total above the lines is money the
// lines do not explain, so it becomes one more line with no item.
// Returns the lines to save and the extra line's amount, or null.
export function settleTotalGap<T extends GapLine>(lines: T[], total: number): { lines: T[]; extraLineTotal: number | null } {
  const lineSum = sumLineTotals(lines);
  if (lineSum === total) {
    return { lines, extraLineTotal: null };
  }
  if (total > lineSum) {
    return { lines, extraLineTotal: total - lineSum };
  }
  let gapLeft = lineSum - total;
  const settled = [...lines];
  for (let index = settled.length - 1; index >= 0 && gapLeft > 0; index -= 1) {
    const line = settled[index] as T;
    const taken = Math.min(gapLeft, Math.max(line.lineTotal, 0));
    settled[index] = { ...line, lineTotal: line.lineTotal - taken, discount: line.discount + taken };
    gapLeft -= taken;
  }
  // Only negative (retur) lines are left to absorb it: the total above them
  // stays unexplained, so it is an extra line like a total above the lines.
  return { lines: settled, extraLineTotal: gapLeft > 0 ? -gapLeft : null };
}

export function sumLineTotals(lines: { lineTotal: number }[]): number {
  return lines.reduce((sum, line) => sum + line.lineTotal, 0);
}

// §12: a price 10 times above or below the saved price is likely a misread.
const IMPLAUSIBLE_FACTOR = 10;

export function isPriceImplausible(unitPrice: number | null, savedPrice: number | null): boolean {
  if (unitPrice === null || savedPrice === null || unitPrice === 0 || savedPrice === 0) {
    return false;
  }
  return unitPrice >= savedPrice * IMPLAUSIBLE_FACTOR || unitPrice * IMPLAUSIBLE_FACTOR <= savedPrice;
}

// §4.1: paid more than the total, so the extra is owed back (Kembalikan).
export function isOverpaid(total: number, payments: { amount: number }[]): boolean {
  return payments.reduce((sum, payment) => sum + payment.amount, 0) > total;
}

// §12: a lump-sum sale and an itemised sale on the same day. A line with an
// item is itemised; a sale with no item at all is a lump sum.
export function mixesLumpSumAndItemised(options: { isItemised: boolean; sameDaySales: { isItemised: boolean }[] }): boolean {
  return options.sameDaySales.some((sale) => sale.isItemised !== options.isItemised);
}
