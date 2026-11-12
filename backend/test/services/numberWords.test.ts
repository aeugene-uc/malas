import { test } from "node:test";
import assert from "node:assert/strict";
import { hasMoneyMarker, parseQuantity, parseRupiah } from "../../src/services/numberWords.js";

test("readsSlangAmountsFromTheFixedList", () => {
  assert.equal(parseRupiah("goceng"), 5_000);
  assert.equal(parseRupiah("ceban"), 10_000);
  assert.equal(parseRupiah("gopek"), 500);
});

test("readsRibuAndJutaInWordsAndDigits", () => {
  assert.equal(parseRupiah("25 ribu"), 25_000);
  assert.equal(parseRupiah("25rb"), 25_000);
  assert.equal(parseRupiah("15k"), 15_000);
  assert.equal(parseRupiah("1,2 juta"), 1_200_000);
  assert.equal(parseRupiah("1,2jt"), 1_200_000);
  assert.equal(parseRupiah("setengah juta"), 500_000);
});

test("readsSpelledOutIndonesianNumbers", () => {
  assert.equal(parseRupiah("dua ratus lima puluh ribu"), 250_000);
  assert.equal(parseRupiah("seratus dua puluh lima ribu"), 125_000);
  assert.equal(parseRupiah("dua belas ribu"), 12_000);
  assert.equal(parseRupiah("seribu lima ratus"), 1_500);
  assert.equal(parseRupiah("dua juta lima ratus ribu"), 2_500_000);
  assert.equal(parseRupiah("selawe ribu"), 25_000);
});

test("treatsDotBeforeThreeDigitsAsThousandsSeparator", () => {
  assert.equal(parseRupiah("Rp 25.000"), 25_000);
  assert.equal(parseRupiah("rp1.250.000"), 1_250_000);
});

test("returnsNullForUnclearAmountsSoTheDraftFlagsThem", () => {
  assert.equal(parseRupiah("ribuan"), null);
  assert.equal(parseRupiah("dua goceng"), null);
  assert.equal(parseRupiah("1,5"), null);
  assert.equal(parseRupiah(""), null);
  assert.equal(parseRupiah("puluh"), null);
});

test("readsBareNumbersAsQuantityWithoutUnit", () => {
  assert.deepEqual(parseQuantity("12"), { quantity: "12", unit: null });
  assert.deepEqual(parseQuantity("selawe"), { quantity: "25", unit: null });
});

test("readsHalfAKiloAsDecimalString", () => {
  assert.deepEqual(parseQuantity("setengah kilo"), { quantity: "0.5", unit: "kg" });
  assert.deepEqual(parseQuantity("1,5 kg"), { quantity: "1.5", unit: "kg" });
  assert.deepEqual(parseQuantity("sekilo"), { quantity: "1", unit: "kg" });
});

test("convertsOnsToKilograms", () => {
  assert.deepEqual(parseQuantity("3 ons"), { quantity: "0.3", unit: "kg" });
});

test("mapsUnitAliasesToSpecUnits", () => {
  assert.deepEqual(parseQuantity("2 porsi"), { quantity: "2", unit: "porsi" });
  assert.deepEqual(parseQuantity("tiga biji"), { quantity: "3", unit: "pcs" });
});

test("returnsNullForZeroOrUnknownQuantity", () => {
  assert.equal(parseQuantity("0 kg"), null);
  assert.equal(parseQuantity("banyak"), null);
  assert.equal(parseQuantity("0,0001 kg"), null);
});

test("tellsMoneyFromABareNumberByItsMarker", () => {
  for (const text of ["25 ribu", "25rb", "15k", "1,2 juta", "Rp 12", "ceban", "25.000"]) {
    assert.equal(hasMoneyMarker(text), true, text);
  }
  for (const text of ["selawe", "12", "setengah", "tiga"]) {
    assert.equal(hasMoneyMarker(text), false, text);
  }
});
