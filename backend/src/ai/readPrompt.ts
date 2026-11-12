import { UNITS } from "../services/numberWords.js";

// Spec §9 "Read voice": the model returns what it heard, as text. Code converts
// number words, computes totals and matches names. Nothing here is arithmetic.

export type Direction = "IN" | "OUT";
export type PaymentLabel = "cash" | "qris" | "transfer";

export type HeardLine = {
  direction: Direction;
  name: string | null;
  quantityText: string | null;
  unit: string | null;
  unitPriceText: string | null;
  amountText: string | null;
  paidText: string | null;
  person: string | null;
  dueInDays: number | null;
  category: string | null;
  paymentLabel: PaymentLabel | null;
  dateOffset: number;
  confidence: number;
};

export const VOICE_SYSTEM_PROMPT = `You read what a small-business owner in Indonesia said about money in and money out, in everyday Indonesian. Return ONLY a JSON object, no explanation and no code fence:

{"lines":[{"direction":"IN"|"OUT","name":string|null,"quantityText":string|null,"unit":string|null,"unitPriceText":string|null,"amountText":string|null,"paidText":string|null,"person":string|null,"dueInDays":number|null,"category":string|null,"paymentLabel":"cash"|"qris"|"transfer"|null,"dateOffset":number,"confidence":number}]}

One object per thing sold, bought or owed, in the order spoken.

You never calculate. Copy every number exactly as it was said, as text, in the *Text fields: "12", "selawe", "25 ribu", "1,2 juta", "setengah kilo". Never convert a number word, add up lines, multiply, or invent a price. If a price was not said, use null.

Fields:
- direction: IN when the owner receives money (jual, omzet, terima, dibayar, bon to a customer). OUT when the owner spends or owes (beli, belanja, bayar, utang to a supplier).
- name: the item or what the money was for. null when only an amount was said ("omzet hari ini 1,2 juta").
- quantityText: how many. A bare number or number word right after an item name, with no ribu, juta, rb, k, Rp or rupiah slang, is a quantity. Example: in "nasi goreng 12, es teh selawe" the quantities are "12" and "selawe", not prices.
- unit: only one of ${UNITS.join(", ")}, when said. Otherwise null.
- unitPriceText: the price of one unit, only when the owner said "per" or "satunya" or similar.
- amountText: money for the whole line, when said with ribu, juta, rb, k, Rp, or slang (goceng, ceban, gopek). A spoken total for a line goes here too: in "nasi 2, 25 ribu aja" the quantityText is "2" and the amountText is "25 ribu".
- paidText: null when nothing was said about paying. "0" when it was not paid yet (bon, utang, tempo, nanti bayar). The amount as text for a part payment ("DP 500 ribu" gives "500 ribu").
- person: a person named for the line ("bon Pak Budi" gives "Pak Budi"), else null.
- dueInDays: days until payment is due when said ("tempo seminggu" gives 7), else null.
- category: a short guess of what kind of income or expense it is, else null.
- paymentLabel: when said (QRIS, transfer, tunai), else null.
- dateOffset: 0 for today. -1 for "kemarin", -2 for "kemarin lusa".
- confidence: 0 to 1, how sure you are of this line. Use below 0.6 when the speech was unclear.

Example input: jual nasi goreng 12, es teh selawe, beli gas 25 ribu, bon Pak Budi 30 ribu
Example output: {"lines":[{"direction":"IN","name":"nasi goreng","quantityText":"12","unit":null,"unitPriceText":null,"amountText":null,"paidText":null,"person":null,"dueInDays":null,"category":null,"paymentLabel":null,"dateOffset":0,"confidence":0.95},{"direction":"IN","name":"es teh","quantityText":"selawe","unit":null,"unitPriceText":null,"amountText":null,"paidText":null,"person":null,"dueInDays":null,"category":null,"paymentLabel":null,"dateOffset":0,"confidence":0.9},{"direction":"OUT","name":"gas","quantityText":null,"unit":null,"unitPriceText":null,"amountText":"25 ribu","paidText":null,"person":null,"dueInDays":null,"category":"bahan bakar","paymentLabel":null,"dateOffset":0,"confidence":0.95},{"direction":"IN","name":null,"quantityText":null,"unit":null,"unitPriceText":null,"amountText":"30 ribu","paidText":"0","person":"Pak Budi","dueInDays":null,"category":null,"paymentLabel":null,"dateOffset":0,"confidence":0.9}]}`;

// The model's reply is a trust boundary (CLAUDE.md), so every field is checked
// and anything outside the contract throws. callModel then retries once.
export function validateHeardLines(value: unknown): HeardLine[] {
  const lines = (value as { lines?: unknown } | null)?.lines;
  if (!Array.isArray(lines)) {
    throw new Error("reply has no lines array");
  }
  return lines.map((line, index) => validateHeardLine(line, index));
}

export function validateHeardLine(value: unknown, index: number): HeardLine {
  const line = (value ?? {}) as Record<string, unknown>;
  const at = `lines[${index}]`;
  const direction = line.direction;
  if (direction !== "IN" && direction !== "OUT") {
    throw new Error(`${at}.direction must be IN or OUT`);
  }
  const paymentLabel = line.paymentLabel ?? null;
  if (paymentLabel !== null && paymentLabel !== "cash" && paymentLabel !== "qris" && paymentLabel !== "transfer") {
    throw new Error(`${at}.paymentLabel is not a known label`);
  }
  return {
    direction,
    name: readText(line.name, `${at}.name`),
    quantityText: readText(line.quantityText, `${at}.quantityText`),
    unit: readText(line.unit, `${at}.unit`),
    unitPriceText: readText(line.unitPriceText, `${at}.unitPriceText`),
    amountText: readText(line.amountText, `${at}.amountText`),
    paidText: readText(line.paidText, `${at}.paidText`),
    person: readText(line.person, `${at}.person`),
    dueInDays: readWholeNumber(line.dueInDays, `${at}.dueInDays`),
    category: readText(line.category, `${at}.category`),
    paymentLabel,
    dateOffset: readWholeNumber(line.dateOffset, `${at}.dateOffset`) ?? 0,
    confidence: readConfidence(line.confidence, `${at}.confidence`),
  };
}

// The model sometimes answers 12 where it was asked for "12".
export function readText(value: unknown, path: string): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === "number") {
    return String(value);
  }
  if (typeof value !== "string") {
    throw new Error(`${path} must be text or null`);
  }
  const trimmed = value.trim();
  return trimmed === "" ? null : trimmed;
}

function readWholeNumber(value: unknown, path: string): number | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new Error(`${path} must be a whole number or null`);
  }
  return value;
}

function readConfidence(value: unknown, path: string): number {
  if (typeof value !== "number" || value < 0 || value > 1) {
    throw new Error(`${path} must be a number from 0 to 1`);
  }
  return value;
}
