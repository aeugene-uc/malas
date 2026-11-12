import type { HeardPriceItem } from "../ai/photoPrompt.js";
import { UNITS, parseRupiah, type Unit } from "./numberWords.js";

// Spec §9 "Read price list": code removes duplicates and rejects prices of 0 or
// above Rp 10.000.000. The result goes to POST /items.

export type PriceListItem = { name: string; price: number; unit: Unit | null };

export type SkippedReason = "UNCLEAR_PRICE" | "PRICE_OUT_OF_RANGE" | "DUPLICATE";

export type PriceListResult = { items: PriceListItem[]; skipped: { name: string; reason: SkippedReason }[] };

const MAX_PRICE = 10_000_000;

export function buildPriceList(heardItems: HeardPriceItem[]): PriceListResult {
  const items: PriceListItem[] = [];
  const skipped: PriceListResult["skipped"] = [];
  const seenKeys = new Set<string>();

  for (const heard of heardItems) {
    const price = parseRupiah(heard.priceText);
    if (price === null) {
      skipped.push({ name: heard.name, reason: "UNCLEAR_PRICE" });
      continue;
    }
    if (price <= 0 || price > MAX_PRICE) {
      skipped.push({ name: heard.name, reason: "PRICE_OUT_OF_RANGE" });
      continue;
    }
    const unit = UNITS.find((candidate) => candidate === heard.unit?.toLowerCase()) ?? null;
    // The first price stays. The same name in a different unit is a different item.
    const key = `${normaliseName(heard.name)}|${unit}`;
    if (seenKeys.has(key)) {
      skipped.push({ name: heard.name, reason: "DUPLICATE" });
      continue;
    }
    seenKeys.add(key);
    items.push({ name: heard.name, price, unit });
  }
  return { items, skipped };
}

function normaliseName(name: string): string {
  return name.toLowerCase().replace(/\s+/g, " ").trim();
}
