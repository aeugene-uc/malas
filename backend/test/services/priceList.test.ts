import { test } from "node:test";
import assert from "node:assert/strict";
import { buildPriceList } from "../../src/services/priceList.js";

test("convertsWrittenPricesAndUnits", () => {
  const { items, skipped } = buildPriceList([
    { name: "Kopi susu", priceText: "15rb", unit: "porsi" },
    { name: "Gula", priceText: "15.000", unit: "KG" },
    { name: "Es teh", priceText: "5000", unit: "gelas" },
  ]);
  assert.deepEqual(items, [
    { name: "Kopi susu", price: 15_000, unit: "porsi" },
    { name: "Gula", price: 15_000, unit: "kg" },
    { name: "Es teh", price: 5_000, unit: null },
  ]);
  assert.deepEqual(skipped, []);
});

test("rejectsPricesOfZeroOrAboveTenMillionButKeepsTenMillion", () => {
  const { items, skipped } = buildPriceList([
    { name: "Gratisan", priceText: "0", unit: null },
    { name: "Mesin", priceText: "10000001", unit: null },
    { name: "Etalase", priceText: "10000000", unit: null },
  ]);
  assert.deepEqual(items.map((item) => item.name), ["Etalase"]);
  assert.deepEqual(skipped, [
    { name: "Gratisan", reason: "PRICE_OUT_OF_RANGE" },
    { name: "Mesin", reason: "PRICE_OUT_OF_RANGE" },
  ]);
});

test("removesDuplicatesByNameAndUnitKeepingTheFirstPrice", () => {
  const { items, skipped } = buildPriceList([
    { name: "Kopi  Susu", priceText: "15000", unit: "porsi" },
    { name: "kopi susu", priceText: "18000", unit: "porsi" },
    { name: "Kopi susu", priceText: "30000", unit: "liter" },
  ]);
  assert.deepEqual(items.map((item) => [item.price, item.unit]), [[15_000, "porsi"], [30_000, "liter"]]);
  assert.deepEqual(skipped, [{ name: "kopi susu", reason: "DUPLICATE" }]);
});

test("skipsAPriceItCouldNotReadInsteadOfGuessing", () => {
  const { items, skipped } = buildPriceList([{ name: "Nasi", priceText: "gratis", unit: null }]);
  assert.deepEqual([items, skipped], [[], [{ name: "Nasi", reason: "UNCLEAR_PRICE" }]]);
});
