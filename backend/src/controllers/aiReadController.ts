import { Readable } from "node:stream";
import type { Request } from "express";
import type { AiImage } from "../ai/provider.js";
import { readAuth } from "../auth.js";
import { ApiError, handleAsync } from "../errors.js";
import * as aiReadService from "../services/aiReadService.js";
import type { ReadRequest } from "../services/aiReadService.js";

// POST /ai/read, in the two shapes the app sends (F6): JSON {kind: "VOICE",
// transcript} for Bicara, and multipart {kind: "PHOTO" | "NOTEBOOK", imageHash,
// image} for Foto.

const MAX_TRANSCRIPT_LENGTH = 4000;
// The app sends photos 1600 px wide at JPEG 70, well under this.
const MAX_PHOTO_BYTES = 8 * 1024 * 1024;
const MAX_FORM_BYTES = MAX_PHOTO_BYTES + 64 * 1024;

export const readInput = handleAsync(async (req, res) => {
  const request = await parseReadRequest(req);
  res.json(await aiReadService.readForStore(readAuth(res).storeId, request));
});

export async function parseReadRequest(req: Request): Promise<ReadRequest> {
  const contentType = req.get("content-type") ?? "";
  return contentType.startsWith("multipart/form-data") ? parsePhoto(req, contentType) : parseVoice(req);
}

function parseVoice(req: Request): ReadRequest {
  const body = (typeof req.body === "object" && req.body !== null ? req.body : {}) as Record<string, unknown>;
  if (body.kind !== "VOICE") {
    throw invalid("kind", "Jenis bacaan tidak dikenal");
  }
  const transcript = typeof body.transcript === "string" ? body.transcript.trim() : "";
  if (transcript === "" || transcript.length > MAX_TRANSCRIPT_LENGTH) {
    throw invalid("transcript", "Rekaman kosong atau terlalu panjang");
  }
  return { kind: "VOICE", transcript };
}

async function parsePhoto(req: Request, contentType: string): Promise<ReadRequest> {
  // The size is checked before anything is read into memory.
  const declaredBytes = Number(req.get("content-length"));
  if (!Number.isFinite(declaredBytes) || declaredBytes <= 0 || declaredBytes > MAX_FORM_BYTES) {
    throw invalid("image", "Foto terlalu besar");
  }
  const form = await readForm(req, contentType);
  const kind = form.get("kind");
  if (kind !== "PHOTO" && kind !== "NOTEBOOK") {
    throw invalid("kind", "Jenis foto tidak dikenal");
  }
  const image = form.get("image");
  if (!(image instanceof File) || image.size === 0 || image.size > MAX_PHOTO_BYTES) {
    throw invalid("image", "Foto tidak ada atau terlalu besar");
  }
  const bytes = Buffer.from(await image.arrayBuffer());
  const mimeType = detectImageType(bytes);
  if (mimeType === null) {
    throw invalid("image", "Berkas ini bukan foto");
  }
  return { kind, image: { mimeType, base64: bytes.toString("base64") } };
}

// Node's own fetch Request parses multipart, so no upload package is needed.
async function readForm(req: Request, contentType: string): Promise<FormData> {
  const webRequest = new globalThis.Request("http://localhost/ai/read", {
    method: "POST",
    headers: { "content-type": contentType },
    body: Readable.toWeb(req) as unknown as ReadableStream<Uint8Array>,
    duplex: "half",
  } as RequestInit & { duplex: "half" });
  try {
    return await webRequest.formData();
  } catch {
    // A body that is not valid multipart cannot be read: the owner can retry.
    throw invalid("image", "Foto tidak terbaca");
  }
}

// The app sends photos without a content type, so the first bytes decide.
function detectImageType(bytes: Buffer): AiImage["mimeType"] | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return "image/jpeg";
  }
  if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return "image/png";
  }
  if (bytes.length >= 12 && bytes.toString("ascii", 0, 4) === "RIFF" && bytes.toString("ascii", 8, 12) === "WEBP") {
    return "image/webp";
  }
  return null;
}

function invalid(field: string, message: string): ApiError {
  return new ApiError({ code: "VALIDATION_FAILED", message, fields: { [field]: message } });
}
