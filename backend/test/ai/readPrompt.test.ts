import { test } from "node:test";
import assert from "node:assert/strict";
import { VOICE_SYSTEM_PROMPT, validateHeardLines } from "../../src/ai/readPrompt.js";

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
