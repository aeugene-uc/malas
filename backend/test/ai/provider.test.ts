import { afterEach, mock, test } from "node:test";
import assert from "node:assert/strict";

// config reads the environment at import, so it is set before the import.
process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test";
process.env.NVIDIA_API_KEY = "test-key";
const { callModel } = await import("../../src/ai/provider.js");

type FetchReply = { status?: number; content?: string; error?: Error };

const request = { systemPrompt: "Return JSON.", userText: "jual 3 kopi 15 ribu" };
const readLines = (value: unknown): { lines: unknown[] } => {
  const lines = (value as { lines?: unknown }).lines;
  if (!Array.isArray(lines)) {
    throw new Error("lines missing");
  }
  return { lines };
};

// Each call to fetch takes the next reply and records which model was asked.
function mockFetch(replies: FetchReply[]): string[] {
  const requestedModels: string[] = [];
  mock.method(globalThis, "fetch", async (_url: string, init: RequestInit) => {
    requestedModels.push((JSON.parse(String(init.body)) as { model: string }).model);
    const reply = replies.shift() ?? { status: 500 };
    if (reply.error !== undefined) {
      throw reply.error;
    }
    const body = { choices: [{ message: { content: reply.content ?? "" } }], usage: { total_tokens: 42 } };
    return new Response(JSON.stringify(body), { status: reply.status ?? 200 });
  });
  mock.method(console, "warn", () => undefined);
  return requestedModels;
}

afterEach(() => mock.restoreAll());

test("returnsValidatedDataFromGemmaOnFirstTry", async () => {
  const models = mockFetch([{ content: '{"lines":[{"name":"kopi"}]}' }]);
  const result = await callModel(request, readLines);
  assert.deepEqual(result, { isRead: true, data: { lines: [{ name: "kopi" }] }, model: "google/gemma-4-31b-it", tokens: 42 });
  assert.deepEqual(models, ["google/gemma-4-31b-it"]);
});

test("readsJsonWrappedInACodeFence", async () => {
  mockFetch([{ content: '```json\n{"lines":[]}\n```' }]);
  const result = await callModel(request, readLines);
  assert.equal(result.isRead, true);
});

test("retriesOnDeepSeekAfterBadJson", async () => {
  const models = mockFetch([{ content: "maaf, saya tidak paham" }, { content: '{"lines":[]}' }]);
  const result = await callModel(request, readLines);
  assert.equal(result.isRead && result.model, "deepseek-ai/deepseek-v4.1-flash");
  assert.deepEqual(models, ["google/gemma-4-31b-it", "deepseek-ai/deepseek-v4.1-flash"]);
});

test("retriesWhenOutputFailsValidation", async () => {
  mockFetch([{ content: '{"items":[]}' }, { content: '{"lines":[]}' }]);
  const result = await callModel(request, readLines);
  assert.equal(result.isRead, true);
});

test("retriesOnGemmaWhenTheRequestHasAnImage", async () => {
  const models = mockFetch([{ status: 503 }, { content: '{"lines":[]}' }]);
  await callModel({ ...request, image: { mimeType: "image/jpeg", base64: "AAAA" } }, readLines);
  assert.deepEqual(models, ["google/gemma-4-31b-it", "google/gemma-4-31b-it"]);
});

test("failsAfterOneRetrySoTheCallerReturnsAnEmptyDraft", async () => {
  const timeout = new DOMException("timed out", "TimeoutError");
  const models = mockFetch([{ error: timeout }, { status: 500 }, { content: '{"lines":[]}' }]);
  const result = await callModel(request, readLines);
  assert.deepEqual(result, {
    isRead: false,
    failures: ["google/gemma-4-31b-it: no reply within 20 s", "deepseek-ai/deepseek-v4.1-flash: HTTP 500"],
  });
  assert.equal(models.length, 2);
});
