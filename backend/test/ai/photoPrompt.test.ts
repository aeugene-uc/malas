import { test } from "node:test";
import assert from "node:assert/strict";
import {
  NOTEBOOK_SYSTEM_PROMPT,
  PRICE_LIST_SYSTEM_PROMPT,
  RECEIPT_SYSTEM_PROMPT,
  validateHeardPage,
  validateHeardPriceList,
} from "../../src/ai/photoPrompt.js";

const validLine = { direction: "OUT", name: "gula", amountText: "30000", confidence: 0.9 };

test("acceptsAPageWithOnlyTheFieldsTheImageShowed", () => {
  const page = validateHeardPage({ seller: "Toko A", lines: [validLine] });
  assert.deepEqual([page.seller, page.date, page.totalText, page.lines[0]?.amountText], ["Toko A", null, null, "30000"]);
});

test("rejectsPageAndPriceListRepliesOutsideTheContract", () => {
  for (const reply of [null, { lines: "gula" }, { lines: [{ ...validLine, direction: "MASUK" }] }, { seller: { name: "A" }, lines: [] }]) {
    assert.throws(() => validateHeardPage(reply), Error, JSON.stringify(reply));
  }
  for (const reply of [null, { items: "kopi" }, { items: [{ name: "kopi" }] }, { items: [{ priceText: "5000" }] }]) {
    assert.throws(() => validateHeardPriceList(reply), Error, JSON.stringify(reply));
  }
});

test("everyPhotoPromptTellsTheModelToCopyAndNotCalculate", () => {
  for (const prompt of [RECEIPT_SYSTEM_PROMPT, NOTEBOOK_SYSTEM_PROMPT, PRICE_LIST_SYSTEM_PROMPT]) {
    assert.match(prompt, /never calculate/i);
    assert.match(prompt, /porsi, pcs, kg/);
  }
});

test("tellsTheModelNotToReadTheCashPaidOrChangeAsTheTotal", () => {
  assert.match(RECEIPT_SYSTEM_PROMPT, /Not the cash paid and not the change \(TUNAI, KEMBALI\)/);
});
