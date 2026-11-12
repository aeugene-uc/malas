import { afterEach, mock, test } from "node:test";
import assert from "node:assert/strict";

// config reads the environment at import, so it is set before the import.
process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test";
process.env.GEMMA_API_KEY = "test-key";
const { readVoiceTranscript } = await import("../../src/services/aiRead.js");

const options = {
  transcript: "jual nasi goreng 12, es teh selawe, beli gas 25 ribu, bon Pak Budi 30 ribu",
  inputId: "input-1",
  todayBusinessDate: "2026-11-12",
};

// The model's reply as text, wrapped the way the API returns it.
function mockModelReplies(texts: string[]): void {
  let calls = 0;
  mock.method(globalThis, "fetch", async () => {
    const text = texts[calls++] ?? "";
    const body = { candidates: [{ content: { parts: [{ text }] } }], usageMetadata: { totalTokenCount: 100 } };
    return new Response(JSON.stringify(body), { status: 200 });
  });
  mock.method(console, "warn", () => undefined);
}

afterEach(() => mock.restoreAll());

const specExampleReply = JSON.stringify({
  lines: [
    { direction: "IN", name: "nasi goreng", quantityText: "12", dateOffset: 0, confidence: 0.95 },
    { direction: "IN", name: "es teh", quantityText: "selawe", dateOffset: 0, confidence: 0.9 },
    { direction: "OUT", name: "gas", amountText: "25 ribu", dateOffset: 0, confidence: 0.95 },
    { direction: "IN", person: "Pak Budi", amountText: "30 ribu", paidText: "0", dateOffset: 0, confidence: 0.9 },
  ],
});

test("readsTheSpecExampleFromATranscriptIntoThreeDrafts", async () => {
  mockModelReplies(["```json\n" + specExampleReply + "\n```"]);
  const result = await readVoiceTranscript(options);
  assert.equal(result.isRead, true);
  if (!result.isRead) return;
  assert.deepEqual(result.drafts.map((draft) => [draft.direction, draft.source, draft.inputId, draft.total]), [
    ["IN", "VOICE", "input-1", 0],
    ["OUT", "VOICE", "input-1", 25_000],
    ["IN", "VOICE", "input-1", 30_000],
  ]);
  assert.equal(result.drafts[0]?.lines[1]?.quantity, "25");
});

test("retriesOnceWhenTheReplyIsNotTheExpectedShape", async () => {
  mockModelReplies(['{"lines":[{"direction":"MASUK"}]}', specExampleReply]);
  const result = await readVoiceTranscript(options);
  assert.equal(result.isRead && result.drafts.length, 3);
});

test("returnsNoDraftsWhenBothTriesFailSoTheReadIsNotCounted", async () => {
  mockModelReplies(["maaf", "maaf lagi"]);
  const result = await readVoiceTranscript(options);
  assert.equal(result.isRead, false);
});
