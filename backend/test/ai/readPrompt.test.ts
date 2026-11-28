import { test } from "node:test";
import assert from "node:assert/strict";
import { VOICE_SYSTEM_PROMPT, validateHeardLines } from "../../src/ai/readPrompt.js";
import { RUPIAH_SLANG } from "../../src/services/numberWords.js";

const validLine = { direction: "IN", name: "kopi", quantityText: "3", dateOffset: 0, confidence: 0.9 };

test("acceptsALineWithOnlyTheFieldsTheModelHad", () => {
  const [line] = validateHeardLines({ lines: [validLine] });
  assert.deepEqual([line?.direction, line?.quantityText, line?.amountText, line?.dateOffset], ["IN", "3", null, 0]);
});

test("turnsANumberTheModelReturnedIntoText", () => {
  const [line] = validateHeardLines({ lines: [{ ...validLine, quantityText: 12 }] });
  assert.equal(line?.quantityText, "12");
});

test("rejectsReplyShapesOutsideTheContract", () => {
  for (const reply of [
    { items: [] },
    null,
    { lines: [{ ...validLine, direction: "MASUK" }] },
    { lines: [{ ...validLine, paymentLabel: "gopay" }] },
    { lines: [{ ...validLine, dueInDays: 1.5 }] },
    { lines: [{ ...validLine, confidence: 7 }] },
    { lines: [{ ...validLine, name: { text: "kopi" } }] },
  ]) {
    assert.throws(() => validateHeardLines(reply), Error, JSON.stringify(reply));
  }
});

test("tellsTheModelTheSelaweRuleWithTheSpecExample", () => {
  assert.match(VOICE_SYSTEM_PROMPT, /es teh selawe/);
  assert.match(VOICE_SYSTEM_PROMPT, /quantities are "12" and "selawe", not prices/);
});

test("namesEverySlangAmountCodeReadsAndTheRuleForMoneyReceivedFromSomeone", () => {
  for (const slang of RUPIAH_SLANG) {
    assert.match(VOICE_SYSTEM_PROMPT, new RegExp(`\\b${slang}\\b`), slang);
  }
  assert.match(VOICE_SYSTEM_PROMPT, /"goban buat bensin" the amountText is "goban"/);
  assert.match(VOICE_SYSTEM_PROMPT, /sewa kamar dari Mas Andi 800 ribu" is rent the owner received/);
});

test("tellsTheModelThatAShopOrSupplierCountsAsPerson", () => {
  assert.match(VOICE_SYSTEM_PROMPT, /a person, shop or supplier named for the line/);
  assert.match(VOICE_SYSTEM_PROMPT, /"di Toko Makmur" gives "Toko Makmur"/);
});
