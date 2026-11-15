import { createHash } from "node:crypto";
import type { Store } from "@prisma/client";
import type { AiImage } from "../ai/provider.js";
import { prisma } from "../db.js";
import { ApiError } from "../errors.js";
import { buildWarning } from "../warnings.js";
import { readPhoto, readVoiceTranscript } from "./aiRead.js";
import { hasReadsLeft, isNewMonth } from "./aiQuota.js";
import { resolveBusinessDate } from "./businessDate.js";
import { savedItemKey, type Draft, type DraftWarning, type SavedItem, type SavedRecords } from "./draftBuilder.js";
import { normaliseName } from "./normaliseName.js";
import { UNITS } from "./numberWords.js";

// POST /ai/read for one store (spec §9, §12, §18): check the monthly limit,
// record the Input, read it with the model, and count it only when it worked.
// Nothing the model returns is saved; the owner saves with Simpan.

export type ReadRequest = { kind: "VOICE"; transcript: string } | { kind: "PHOTO" | "NOTEBOOK"; image: AiImage };

export type ReadResponse = { inputId: string; drafts: Draft[]; warnings: DraftWarning[] };

export async function readForStore(storeId: string, request: ReadRequest): Promise<ReadResponse> {
  const now = new Date();
  const store = await prisma.store.findUniqueOrThrow({ where: { id: storeId } });
  if (!hasReadsLeft(store, now)) {
    throw new ApiError({ code: "PLAN_LIMIT_REACHED", message: "Jatah baca AI bulan ini sudah habis. Ketik tetap bisa." });
  }
  // The server hashes the photo itself rather than trusting the app's hash.
  const imageHash = request.kind === "VOICE" ? null : createHash("sha256").update(request.image.base64, "base64").digest("hex");
  const isRepeatPhoto = imageHash !== null && (await prisma.input.count({ where: { storeId, imageHash, status: "READ" } })) > 0;
  // Photos are read and not kept, so only their hash is stored.
  const input = await prisma.input.create({
    data: { storeId, kind: request.kind, transcript: request.kind === "VOICE" ? request.transcript : null, imageHash },
  });

  const todayBusinessDate = resolveBusinessDate({ now, timezone: store.timezone, dayChangeHour: store.dayChangeHour });
  const saved = await loadSavedRecords(storeId);
  const result =
    request.kind === "VOICE"
      ? await readVoiceTranscript({ transcript: request.transcript, inputId: input.id, todayBusinessDate, saved })
      : await readPhoto({ source: request.kind, image: request.image, inputId: input.id, todayBusinessDate, saved });

  if (!result.isRead) {
    await prisma.input.update({ where: { id: input.id }, data: { status: "FAILED" } });
    throw new ApiError({ code: "AI_READ_FAILED", message: "Belum bisa membaca. Coba lagi, atau ketik saja." });
  }
  await prisma.input.update({ where: { id: input.id }, data: { status: "READ", model: result.model, tokens: result.tokens } });
  // Spec §7.3: the same photo twice is a soft duplicate warning, and reading it
  // again does not use up another read.
  if (!isRepeatPhoto) {
    await countRead(store, now);
  }
  const warnings = [...result.warnings];
  if (isRepeatPhoto && result.drafts.length > 0) {
    warnings.push({ ...buildWarning("DUPLICATE_SUSPECTED"), draftIndex: 0, lineIndex: 0 });
  }
  return { inputId: input.id, drafts: result.drafts, warnings };
}

// The count restarts at 1 on the first read of a new month in the store's
// calendar; otherwise it goes up by one in the database, so two reads at once
// both count.
async function countRead(store: Store, now: Date): Promise<void> {
  await prisma.store.update({
    where: { id: store.id },
    data: isNewMonth(store.aiReadsResetAt, store.timezone, now) ? { aiReadsThisMonth: 1, aiReadsResetAt: now } : { aiReadsThisMonth: { increment: 1 } },
  });
}

// A warung has tens or a few hundred items, so all of them are loaded once per
// read and matched in memory.
async function loadSavedRecords(storeId: string): Promise<SavedRecords> {
  const [items, people] = await Promise.all([
    prisma.item.findMany({ where: { storeId }, select: { id: true, normalisedName: true, kind: true, categoryId: true, unit: true, savedPrice: true } }),
    prisma.person.findMany({ where: { storeId }, select: { id: true, name: true } }),
  ]);
  const itemsByKey = new Map<string, SavedItem>();
  for (const item of items) {
    const unit = UNITS.find((candidate) => candidate === item.unit) ?? null;
    itemsByKey.set(savedItemKey(item.kind === "SOLD" ? "IN" : "OUT", item.normalisedName), {
      id: item.id,
      categoryId: item.categoryId,
      unit,
      savedPrice: item.savedPrice,
    });
  }
  const personIdsByName = new Map<string, string>();
  for (const person of people) {
    const key = normaliseName(person.name);
    if (!personIdsByName.has(key)) {
      personIdsByName.set(key, person.id);
    }
  }
  return { itemsByKey, personIdsByName };
}
