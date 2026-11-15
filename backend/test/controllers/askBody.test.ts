import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import type { Server } from "node:http";

process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test-secret";
process.env.GEMMA_API_KEY = "test-key";
const { readAskBody } = await import("../../src/controllers/askController.js");
const { createApp } = await import("../../src/app.js");

test("readsAQuestionAndAFollowUpAsF8SendsThem", () => {
  assert.deepEqual(readAskBody({ question: " klo thn kmrn? ", previousQuestion: "pemasukan bln ini brp?" }), {
    question: "klo thn kmrn?",
    previousQuestion: "pemasukan bln ini brp?",
  });
  assert.deepEqual(readAskBody({ question: "siapa yang belum bayar?" }), { question: "siapa yang belum bayar?", previousQuestion: null });
});

test("rejectsAnEmptyOrOverlongQuestionAndAPreviousQuestionThatIsNotText", () => {
  assert.throws(() => readAskBody({ question: "   " }), /Tulis pertanyaan/);
  assert.throws(() => readAskBody({ question: "x".repeat(301) }), /Tulis pertanyaan/);
  assert.throws(() => readAskBody({ question: "untung?", previousQuestion: 42 }));
});

let server: Server;
before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
});
after(() => server.close());

test("refusesTanyaWithoutSigningIn", async () => {
  const port = (server.address() as { port: number }).port;
  const response = await fetch(`http://127.0.0.1:${port}/api/v1/ai/ask`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ question: "untung bulan ini?" }),
  });
  assert.equal(response.status, 401);
});
