import { test } from "node:test";
import assert from "node:assert/strict";
import { ASK_SYSTEM_PROMPT, validateAskIntent } from "../../src/ai/askPrompt.js";

test("acceptsAMinimalReplyAndDefaultsToThisMonth", () => {
  const intent = validateAskIntent({ function: "totals" });
  assert.deepEqual(intent, {
    function: "totals",
    period: "bulan",
    periodOffset: 0,
    comparePeriodOffset: null,
    direction: null,
    name: null,
    balance: null,
  });
});

test("rejectsRepliesOutsideTheContract", () => {
  for (const reply of [
    null,
    { function: "forecast" },
    { function: "totals", period: "dekade" },
    { function: "totals", periodOffset: 1 },
    { function: "totals", periodOffset: -1.5 },
    { function: "totals", direction: "MASUK" },
    { function: "openBalances", balance: "SEMUA" },
    { function: "compare", comparePeriodOffset: "lalu" },
  ]) {
    assert.throws(() => validateAskIntent(reply), Error, JSON.stringify(reply));
  }
});

test("tellsTheModelNotToAnswerAndHowToUseThePreviousQuestion", () => {
  assert.match(ASK_SYSTEM_PROMPT, /never answer the question and never write a number/);
  assert.match(ASK_SYSTEM_PROMPT, /"klo thn kmrn\?" means totals, direction IN, tahun -1/);
  assert.match(ASK_SYSTEM_PROMPT, /causes \("kenapa sepi\?"\)/);
});
