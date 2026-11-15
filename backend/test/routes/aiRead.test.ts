import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import type { Server } from "node:http";
import express from "express";

// config reads the environment at import, so it is set before the import. No
// request here reaches the database or the model.
process.env.DATABASE_URL = "mysql://test@localhost:3306/test";
process.env.JWT_SECRET = "test-secret";
process.env.GEMMA_API_KEY = "test-key";
const { parseReadRequest } = await import("../../src/controllers/aiReadController.js");
const { handleAsync, handleError } = await import("../../src/errors.js");
const { createApp } = await import("../../src/app.js");

// A tiny app around the parser, so each test sends a real JSON or multipart
// request and sees what the route would read.
const parserApp = express()
  .use(express.json())
  .post(
    "/parse",
    handleAsync(async (req, res) => {
      const parsed = await parseReadRequest(req);
      res.json(parsed.kind === "VOICE" ? parsed : { kind: parsed.kind, mimeType: parsed.image.mimeType, bytes: Buffer.from(parsed.image.base64, "base64").length });
    }),
  )
  .use(handleError);

let parserServer: Server;
let appServer: Server;
const urlOf = (server: Server) => `http://127.0.0.1:${(server.address() as { port: number }).port}`;

before(async () => {
  parserServer = parserApp.listen(0);
  appServer = createApp().listen(0);
  await Promise.all([parserServer, appServer].map((server) => new Promise((resolve) => server.once("listening", resolve))));
});

after(() => {
  parserServer.close();
  appServer.close();
});

const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);
const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0]);

async function postJson(body: unknown) {
  const response = await fetch(`${urlOf(parserServer)}/parse`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  return { status: response.status, body: (await response.json()) as Record<string, unknown> & { error?: { fields: Record<string, string> } } };
}

// Like the app: no content type on the image part.
async function postPhoto(fields: { kind?: string; image?: Uint8Array }) {
  const form = new FormData();
  if (fields.kind !== undefined) form.append("kind", fields.kind);
  form.append("imageHash", "from-the-app");
  if (fields.image !== undefined) form.append("image", new Blob([fields.image]), "foto.jpg");
  const response = await fetch(`${urlOf(parserServer)}/parse`, { method: "POST", body: form });
  return { status: response.status, body: (await response.json()) as Record<string, unknown> & { error?: { message: string; fields: Record<string, string> } } };
}

test("readsAVoiceTranscriptAndTrimsIt", async () => {
  const { status, body } = await postJson({ kind: "VOICE", transcript: "  jual kopi 3  " });
  assert.deepEqual([status, body], [200, { kind: "VOICE", transcript: "jual kopi 3" }]);
});

test("rejectsAnEmptyTranscriptOrAnUnknownKind", async () => {
  assert.deepEqual(Object.keys((await postJson({ kind: "VOICE", transcript: "  " })).body.error?.fields ?? {}), ["transcript"]);
  assert.deepEqual(Object.keys((await postJson({ kind: "TYPED", transcript: "kopi" })).body.error?.fields ?? {}), ["kind"]);
});

test("readsAReceiptAndANotebookPhotoByTheirFirstBytes", async () => {
  assert.deepEqual((await postPhoto({ kind: "PHOTO", image: jpeg })).body, { kind: "PHOTO", mimeType: "image/jpeg", bytes: 8 });
  assert.deepEqual((await postPhoto({ kind: "NOTEBOOK", image: png })).body, { kind: "NOTEBOOK", mimeType: "image/png", bytes: 10 });
});

test("rejectsAFileThatIsNotAPhotoAMissingPhotoOrAnUnknownKind", async () => {
  const notPhoto = await postPhoto({ kind: "PHOTO", image: new TextEncoder().encode("bukan foto") });
  assert.deepEqual([notPhoto.status, notPhoto.body.error?.message], [400, "Berkas ini bukan foto"]);
  assert.deepEqual(Object.keys((await postPhoto({ kind: "PHOTO" })).body.error?.fields ?? {}), ["image"]);
  assert.deepEqual(Object.keys((await postPhoto({ kind: "PRICE_LIST", image: jpeg })).body.error?.fields ?? {}), ["kind"]);
});

test("rejectsAPhotoOverEightMegabytesBeforeReadingIt", async () => {
  const tooBig = new Uint8Array(9 * 1024 * 1024);
  tooBig.set(jpeg);
  const { status, body } = await postPhoto({ kind: "PHOTO", image: tooBig });
  assert.deepEqual([status, body.error?.message], [400, "Foto terlalu besar"]);
});

test("refusesTheReadRouteWithoutSigningIn", async () => {
  const response = await fetch(`${urlOf(appServer)}/api/v1/ai/read`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ kind: "VOICE", transcript: "jual kopi 3" }),
  });
  assert.equal(response.status, 401);
});
