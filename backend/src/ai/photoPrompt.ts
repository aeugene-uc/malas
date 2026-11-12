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

const LINE_FIELDS = `{"direction":"IN"|"OUT","name":string|null,"quantityText":string|null,"unit":string|null,"unitPriceText":string|null,"amountText":string|null,"confidence":number}`;

const SHARED_RULES = `You never calculate or correct anything. Copy numbers exactly as the image shows them, even when a total does not add up. If something is not readable, use null and a confidence below 0.6.

Line fields:
- direction: see the rules for this kind of page.
- name: the item or what the money was for, without the words jual, beli or bayar. null when the row only has an amount.
- quantityText: how many, as written ("2", "0,5").
- unit: only one of ${UNITS.join(", ")}, when written. A printed L or ltr is liter. Otherwise null.
- unitPriceText: the price of one unit, when the row shows one.
- amountText: the total of that row, as written.
- confidence: 0 to 1, how sure you are of the row.

The message gives today's date. Use it to fill in a year that the page leaves out. Write dates as YYYY-MM-DD.`;

export const RECEIPT_SYSTEM_PROMPT = `You read a photo of a receipt, supplier nota or sales note from a small business in Indonesia. Return ONLY a JSON object, no explanation and no code fence:

{"seller":string|null,"date":string|null,"totalText":string|null,"lines":[${LINE_FIELDS}]}

- seller: the shop name printed at the top.
- date: the date printed on it.
- totalText: the grand total as printed (TOTAL, JUMLAH, GRAND TOTAL). Not the cash paid and not the change (TUNAI, KEMBALI).
- lines: one per item row. Skip subtotal, discount, tax, payment and change rows. The printed total already covers them.
- Write printed amounts as digits only, without Rp, dots or commas: "30.000" becomes "30000".
- direction: OUT when the owner bought the goods. That is the usual case for a store receipt or a supplier nota. IN only when the document is a sale the owner made.

${SHARED_RULES}`;

export const NOTEBOOK_SYSTEM_PROMPT = `You read a photo of a handwritten notebook page where a small business owner in Indonesia wrote down money in and money out. Return ONLY a JSON object, no explanation and no code fence:

{"date":string|null,"lines":[${LINE_FIELDS}]}

- date: the date written at the top of the page.
- lines: one per row, in order.
- Copy handwritten amounts as written, including "rb", "k", "jt" or dots: "15rb", "25.000".
- direction: IN for sales and money received (jual, masuk, terima). OUT for purchases and expenses (beli, belanja, keluar, bayar). Use the column or the word on the row.

${SHARED_RULES}`;

export const PRICE_LIST_SYSTEM_PROMPT = `You read a photo of a price list or menu from a small business in Indonesia. Return ONLY a JSON object, no explanation and no code fence:

{"items":[{"name":string,"priceText":string,"unit":string|null}]}

- One object per item that has a price.
- priceText: the price as written ("15.000", "15rb"). Do not convert it.
- unit: only one of ${UNITS.join(", ")}, when written. Otherwise null.
- You never calculate. Skip anything without a price.`;

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
