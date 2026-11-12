import type { HeardLine, PaymentLabel } from "../ai/readPrompt.js";
import { buildWarning, type Warning } from "../warnings.js";
import { UNITS, hasMoneyMarker, parseQuantity, parseRupiah, type Unit } from "./numberWords.js";

// Spec §9: code converts the numbers the model heard, groups lines into
// transactions and computes the totals. Matching names to items and filling
// saved prices need the database and come after this step, so a line whose price
// is unknown keeps `lineTotal: null`.

export type InputSource = "VOICE" | "PHOTO" | "NOTEBOOK";

export type DraftLine = {
  itemId: null;
  itemName: string | null;
  categoryId: null;
  // The model's guess. The server picks the real category from the fixed list.
  categoryHint: string | null;
  quantity: string | null;
  unit: Unit | null;
  unitPrice: number | null;
  lineTotal: number | null;
};

export type DraftPayment = { date: string; amount: number; label: PaymentLabel };

// The POST /transactions body from the backend contract.
export type Draft = {
  // Left out when the owner meant today. The server resolves it (spec §10).
  businessDate?: string;
  direction: "IN" | "OUT";
  total: number;
  personId: null;
  personName: string | null;
  dueDate: string | null;
  source: InputSource;
  inputId: string | null;
  note: null;
  lines: DraftLine[];
  payments: DraftPayment[];
};

export type DraftWarning = Warning & { draftIndex: number; lineIndex: number };

export type BuiltDrafts = { drafts: Draft[]; warnings: DraftWarning[] };

type BuildOptions = {
  heardLines: HeardLine[];
  source: InputSource;
  inputId: string | null;
  // The store's business date today, from its timezone and day-change hour.
  todayBusinessDate: string;
};

const LOW_CONFIDENCE = 0.6;

export function buildDrafts(options: BuildOptions): BuiltDrafts {
  const { heardLines, source, inputId, todayBusinessDate } = options;
  const drafts: Draft[] = [];
  const warnings: DraftWarning[] = [];
  const draftIndexByKey = new Map<string, number>();

  for (const heard of heardLines) {
    const key = groupKey(heard);
    let draftIndex = draftIndexByKey.get(key);
    if (draftIndex === undefined) {
      draftIndex = drafts.push(startDraft(heard, { source, inputId, todayBusinessDate })) - 1;
      draftIndexByKey.set(key, draftIndex);
    }
    const draft = drafts[draftIndex] as Draft;
    const { line, unclearFields } = buildLine(heard);
    draft.lines.push(line);
    if (unclearFields.length > 0 || heard.confidence < LOW_CONFIDENCE) {
      warnings.push({ ...buildWarning("UNCLEAR_READ"), draftIndex, lineIndex: draft.lines.length - 1 });
    }
  }

  for (const draft of drafts) {
    draft.total = draft.lines.reduce((sum, line) => sum + (line.lineTotal ?? 0), 0);
  }
  addPayments(drafts, heardLines, draftIndexByKey, todayBusinessDate);
  return { drafts, warnings };
}

// Lines from one sale or one purchase belong to one transaction (spec §4.1),
// so lines that differ in direction, person, date or how they were paid do not.
function groupKey(heard: HeardLine): string {
  return [heard.direction, heard.person, heard.dueInDays, heard.dateOffset, heard.paidText, heard.paymentLabel].join("|");
}

function startDraft(
  heard: HeardLine,
  context: { source: InputSource; inputId: string | null; todayBusinessDate: string },
): Draft {
  const businessDate = addDays(context.todayBusinessDate, heard.dateOffset);
  const draft: Draft = {
    direction: heard.direction,
    total: 0,
    personId: null,
    personName: heard.person,
    // "Tempo seminggu" counts from the day of the sale, not from today.
    dueDate: heard.dueInDays === null ? null : addDays(businessDate, heard.dueInDays),
    source: context.source,
    inputId: context.inputId,
    note: null,
    lines: [],
    payments: [],
  };
  if (heard.dateOffset !== 0) {
    draft.businessDate = businessDate;
  }
  return draft;
}

// A field the model gave but code could not turn into a number is unclear: it
// stays null and the line is flagged, never guessed (spec §7.3).
function buildLine(heard: HeardLine): { line: DraftLine; unclearFields: string[] } {
  const unclearFields: string[] = [];
  const { quantityText, amountText } = moveBareNumberToQuantity(heard);

  const quantity = convert(quantityText, parseQuantity, "quantity", unclearFields);
  const unitPrice = convert(heard.unitPriceText, parseRupiah, "unitPrice", unclearFields);
  const amount = convert(amountText, parseRupiah, "amount", unclearFields);

  const line: DraftLine = {
    itemId: null,
    itemName: heard.name,
    categoryId: null,
    categoryHint: heard.category,
    quantity: quantity?.quantity ?? null,
    unit: quantity?.unit ?? readUnit(heard.unit),
    unitPrice,
    lineTotal: computeLineTotal({ amount, quantity: quantity?.quantity ?? null, unitPrice }),
  };
  return { line, unclearFields };
}

// The model sometimes puts "selawe" in amountText. Without ribu, juta, Rp or
// slang it is a quantity, and a quantity is never a few rupiah (spec §7.3).
function moveBareNumberToQuantity(heard: HeardLine): { quantityText: string | null; amountText: string | null } {
  const { quantityText, amountText } = heard;
  if (quantityText !== null || amountText === null || hasMoneyMarker(amountText)) {
    return { quantityText, amountText };
  }
  const asRupiah = parseRupiah(amountText);
  const isSmallNumber = asRupiah !== null && asRupiah < 1000;
  return isSmallNumber ? { quantityText: amountText, amountText: null } : { quantityText, amountText };
}

function convert<T>(
  text: string | null,
  parse: (text: string) => T | null,
  fieldName: string,
  unclearFields: string[],
): T | null {
  if (text === null) {
    return null;
  }
  const value = parse(text);
  if (value === null) {
    unclearFields.push(fieldName);
  }
  return value;
}

function readUnit(text: string | null): Unit | null {
  return UNITS.find((unit) => unit === text?.toLowerCase()) ?? null;
}

// Spec §10: a spoken or printed total wins, otherwise quantity x unit price.
function computeLineTotal(parts: { amount: number | null; quantity: string | null; unitPrice: number | null }): number | null {
  if (parts.amount !== null) {
    return parts.amount;
  }
  if (parts.quantity === null || parts.unitPrice === null) {
    return null;
  }
  return Math.round((toThousandths(parts.quantity) * parts.unitPrice) / 1000);
}

// "0.5" is 500, so money never goes through a float multiplication.
function toThousandths(quantity: string): number {
  const [whole = "0", fraction = ""] = quantity.split(".");
  return Number(whole) * 1000 + Number(fraction.padEnd(3, "0"));
}

// Nothing said about paying means paid in full on the day. "bon" or "tempo"
// means nothing paid yet, and "DP 500 ribu" an open balance (spec §7.3).
function addPayments(
  drafts: Draft[],
  heardLines: HeardLine[],
  draftIndexByKey: Map<string, number>,
  todayBusinessDate: string,
): void {
  for (const heard of heardLines) {
    const draft = drafts[draftIndexByKey.get(groupKey(heard)) as number] as Draft;
    if (draft.payments.length > 0 || draft.total === 0) {
      continue;
    }
    const paid = heard.paidText === null ? draft.total : parseRupiah(heard.paidText);
    if (paid !== null && paid > 0) {
      draft.payments.push({
        date: draft.businessDate ?? todayBusinessDate,
        amount: paid,
        label: heard.paymentLabel ?? "cash",
      });
    }
  }
}

// Plain calendar arithmetic on a date string, so no clock or timezone is read.
function addDays(date: string, days: number): string {
  const moved = new Date(`${date}T00:00:00Z`);
  moved.setUTCDate(moved.getUTCDate() + days);
  return moved.toISOString().slice(0, 10);
}
