import { afterEach, mock, test } from "node:test";
import assert from "node:assert/strict";

// config reads the environment at import, so it is set before the import.
process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test";
process.env.GEMMA_API_KEY = "test-key";
const { callModel } = await import("../../src/ai/provider.js");

type Part = { text: string; thought?: boolean };
type FetchReply = { status?: number; parts?: Part[]; error?: Error };

const request = { systemPrompt: "Return JSON.", userText: "jual 3 kopi 15 ribu" };
const readLines = (value: unknown): { lines: unknown[] } => {
  const lines = (value as { lines?: unknown }).lines;
  if (!Array.isArray(lines)) {
    throw new Error("lines missing");
  }
  return { lines };
};

// Each call to fetch takes the next reply and records the request body.
function mockFetch(replies: FetchReply[]): Record<string, unknown>[] {
  const requestBodies: Record<string, unknown>[] = [];
  mock.method(globalThis, "fetch", async (_url: string, init: RequestInit) => {
    requestBodies.push(JSON.parse(String(init.body)) as Record<string, unknown>);
    const reply = replies.shift() ?? { status: 500 };
    if (reply.error !== undefined) {
      throw reply.error;
    }
    const body = { candidates: [{ content: { parts: reply.parts ?? [] } }], usageMetadata: { totalTokenCount: 42 } };
    return new Response(JSON.stringify(body), { status: reply.status ?? 200 });
  });
  mock.method(console, "warn", () => undefined);
  return requestBodies;
}

afterEach(() => mock.restoreAll());

test("returnsValidatedDataOnFirstTry", async () => {
  const bodies = mockFetch([{ parts: [{ text: '{"lines":[{"name":"kopi"}]}' }] }]);
  const result = await callModel(request, readLines);
  assert.deepEqual(result, { isRead: true, data: { lines: [{ name: "kopi" }] }, model: "gemini-3.5-flash-lite", tokens: 42 });
  assert.equal(bodies.length, 1);
});

test("ignoresThoughtPartsAndReadsOnlyTheAnswer", async () => {
  mockFetch([{ parts: [{ text: "The user sells coffee {", thought: true }, { text: '```json\n{"lines":[]}\n```' }] }]);
  const result = await callModel(request, readLines);
  assert.deepEqual(result.isRead && result.data, { lines: [] });
});

test("retriesOnceAfterBadJson", async () => {
  const bodies = mockFetch([{ parts: [{ text: "maaf, saya tidak paham" }] }, { parts: [{ text: '{"lines":[]}' }] }]);
  const result = await callModel(request, readLines);
  assert.equal(result.isRead, true);
  assert.equal(bodies.length, 2);
});

test("retriesWhenOutputFailsValidation", async () => {
  mockFetch([{ parts: [{ text: '{"items":[]}' }] }, { parts: [{ text: '{"lines":[]}' }] }]);
  const result = await callModel(request, readLines);
  assert.equal(result.isRead, true);
});

test("sendsTheImageBeforeTheText", async () => {
  const bodies = mockFetch([{ parts: [{ text: '{"lines":[]}' }] }]);
  await callModel({ ...request, image: { mimeType: "image/jpeg", base64: "AAAA" } }, readLines);
  const contents = bodies[0]?.contents as { parts: Record<string, unknown>[] }[];
  assert.deepEqual(contents[0]?.parts, [
    { inline_data: { mime_type: "image/jpeg", data: "AAAA" } },
    { text: "jual 3 kopi 15 ribu" },
  ]);
});

test("failsAfterOneRetrySoTheCallerReturnsAnEmptyDraft", async () => {
  const timeout = new DOMException("timed out", "TimeoutError");
  const bodies = mockFetch([{ error: timeout }, { status: 500 }, { parts: [{ text: '{"lines":[]}' }] }]);
  const result = await callModel(request, readLines);
  assert.deepEqual(result, { isRead: false, failures: ["attempt 1: no reply within 20 s", "attempt 2: HTTP 500"] });
  assert.equal(bodies.length, 2);
});
