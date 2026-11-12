import { afterEach, mock, test } from "node:test";
import assert from "node:assert/strict";

// config reads the environment at import, so it is set before the import.
process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test";
process.env.GEMMA_API_KEY = "test-key";
const { readPhoto, readPriceList, readVoiceTranscript } = await import("../../src/services/aiRead.js");

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

const image = { mimeType: "image/jpeg" as const, base64: "AAAA" };
const photoOptions = { image, inputId: "input-2", todayBusinessDate: "2026-11-12" };

test("readsAReceiptPhotoIntoOneDraftWithTheSellerAndPrintedTotal", async () => {
  mockModelReplies([
    JSON.stringify({
      seller: "Toko Sumber Rejeki",
      date: "2026-11-10",
      totalText: "48000",
      lines: [
        { direction: "OUT", name: "Gula", quantityText: "2", unit: "kg", amountText: "30000", confidence: 0.95 },
        { direction: "OUT", name: "Minyak", quantityText: "1", unit: "liter", amountText: "18000", confidence: 0.95 },
      ],
    }),
  ]);
  const result = await readPhoto({ ...photoOptions, source: "PHOTO" });
  assert.equal(result.isRead, true);
  if (!result.isRead) return;
  const [draft] = result.drafts;
  assert.deepEqual(
    [result.drafts.length, draft?.source, draft?.personName, draft?.businessDate, draft?.total, draft?.lines.length],
    [1, "PHOTO", "Toko Sumber Rejeki", "2026-11-10", 48_000, 2],
  );
  assert.deepEqual(result.warnings, []);
});

test("datesANotebookPageByItsPageDate", async () => {
  mockModelReplies([
    JSON.stringify({ date: "2026-11-09", lines: [{ direction: "IN", name: "kopi", quantityText: "3", amountText: "45rb", confidence: 0.8 }] }),
  ]);
  const result = await readPhoto({ ...photoOptions, source: "NOTEBOOK" });
  assert.equal(result.isRead && result.drafts[0]?.businessDate, "2026-11-09");
});

test("returnsNoDraftsWhenAPhotoReadFailsTwice", async () => {
  mockModelReplies(["bukan json", '{"seller":"A"}']);
  const result = await readPhoto({ ...photoOptions, source: "PHOTO" });
  assert.equal(result.isRead, false);
});

test("readsAPriceListIntoItemsWithoutDuplicatesOrImpossiblePrices", async () => {
  mockModelReplies([
    JSON.stringify({
      items: [
        { name: "Kopi susu", priceText: "15rb", unit: "porsi" },
        { name: "kopi susu", priceText: "16rb", unit: "porsi" },
        { name: "Mesin kopi", priceText: "12000000", unit: null },
        { name: "Es teh", priceText: "5.000", unit: null },
      ],
    }),
  ]);
  const result = await readPriceList({ image });
  assert.equal(result.isRead, true);
  if (!result.isRead) return;
  assert.deepEqual(result.items.map((item) => [item.name, item.price]), [["Kopi susu", 15_000], ["Es teh", 5_000]]);
  assert.deepEqual(result.skipped.map((entry) => entry.reason), ["DUPLICATE", "PRICE_OUT_OF_RANGE"]);
});
