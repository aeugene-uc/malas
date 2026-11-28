import { UNITS } from "../services/numberWords.js";
import { readText, validateHeardLine, type HeardLine } from "./readPrompt.js";

// Spec §9 "Read photo", "Read notebook page" and "Read price list". As with
// voice, the model copies what the image shows as text and code does the
// numbers, the checks and the matching.

export type HeardPage = {
  seller: string | null;
  date: string | null;
  totalText: string | null;
  lines: HeardLine[];
};

export type HeardPriceItem = { name: string; priceText: string; unit: string | null };

const LINE_FIELDS = `{"direction":"IN"|"OUT","name"?:string,"quantityText"?:string,"unit"?:string,"unitPriceText"?:string,"amountText"?:string,"confidence":number}`;

const SHARED_RULES = `Never calculate or correct anything. Copy numbers exactly as shown, even when a total does not add up. If unreadable, omit the field and use a confidence below 0.6.
Return compact single-line JSON with no extra whitespace and omit null fields.
Line fields:
- direction: see the page rule above.
- name: item or purpose, without jual, beli or bayar. Omit when the row only has an amount.
- quantityText: count as written ("2", "0,5").
- unit: only ${UNITS.join(", ")} when written (printed L or ltr is liter).
- unitPriceText: price of one unit, when shown.
- amountText: row total, as written.
- confidence: 0 to 1.
Use today's date in the message to fill a missing year. Write dates as YYYY-MM-DD.`;

export const RECEIPT_SYSTEM_PROMPT = `Read this Indonesian receipt, supplier nota or sales note. Return ONLY compact single-line JSON, no explanation and no code fence:
{"seller"?:string,"date"?:string,"totalText"?:string,"lines":[${LINE_FIELDS}]}
- seller: shop name printed at the top.
- date: date printed on it.
- totalText: grand total as printed (TOTAL, JUMLAH, GRAND TOTAL). Not the cash paid and not the change (TUNAI, KEMBALI).
- lines: one per item row. Skip subtotal, discount, tax, payment and change rows.
- Write printed amounts as digits only, without Rp, dots or commas: "30.000" becomes "30000".
- direction: OUT for a purchase receipt or supplier nota; IN only for a sale the owner made.
${SHARED_RULES}`;

export const NOTEBOOK_SYSTEM_PROMPT = `Read this Indonesian handwritten notebook page of money in and out. Return ONLY compact single-line JSON, no explanation and no code fence:
{"date"?:string,"lines":[${LINE_FIELDS}]}
- date: date written at the top.
- lines: one per row, in order.
- Copy handwritten amounts as written, including "rb", "k", "jt" or dots: "15rb", "25.000".
- direction: IN for sales/money received (jual, masuk, terima); OUT for purchases/expenses (beli, belanja, keluar, bayar). Use the column or the word on the row.
${SHARED_RULES}`;

export const PRICE_LIST_SYSTEM_PROMPT = `Read this Indonesian price list or menu photo. Return ONLY compact single-line JSON, no explanation and no code fence, and omit absent fields:
{"items":[{"name":string,"priceText":string,"unit"?:string}]}
- One object per item that has a price.
- priceText: price as written ("15.000", "15rb"). Do not convert it.
- unit: only ${UNITS.join(", ")} when written.
- Never calculate. Skip anything without a price.`;

// The model's reply is a trust boundary (CLAUDE.md), so every field is checked
// and anything outside the contract throws. callModel then retries once.
export function validateHeardPage(value: unknown): HeardPage {
  const page = (value ?? {}) as Record<string, unknown>;
  if (!Array.isArray(page.lines)) {
    throw new Error("reply has no lines array");
  }
  return {
    seller: readText(page.seller, "seller"),
    date: readText(page.date, "date"),
    totalText: readText(page.totalText, "totalText"),
    lines: page.lines.map((line, index) => validateHeardLine(line, index)),
  };
}

export function validateHeardPriceList(value: unknown): HeardPriceItem[] {
  const items = (value as { items?: unknown } | null)?.items;
  if (!Array.isArray(items)) {
    throw new Error("reply has no items array");
  }
  return items.map((item, index) => {
    const entry = (item ?? {}) as Record<string, unknown>;
    const name = readText(entry.name, `items[${index}].name`);
    const priceText = readText(entry.priceText, `items[${index}].priceText`);
    if (name === null || priceText === null) {
      throw new Error(`items[${index}] needs a name and a price`);
    }
    return { name, priceText, unit: readText(entry.unit, `items[${index}].unit`) };
  });
}
