import { callModel, type AiImage } from "../ai/provider.js";
import {
  NOTEBOOK_SYSTEM_PROMPT,
  PRICE_LIST_SYSTEM_PROMPT,
  RECEIPT_SYSTEM_PROMPT,
  validateHeardPage,
  validateHeardPriceList,
} from "../ai/photoPrompt.js";
import { VOICE_SYSTEM_PROMPT, validateHeardLines } from "../ai/readPrompt.js";
import { buildDrafts, type BuiltDrafts } from "./draftBuilder.js";
import { buildPriceList, type PriceListResult } from "./priceList.js";

// Spec §9 "Read voice". A failed read returns no drafts so the caller shows an
// empty draft and does not count the read against the plan quota (spec §12).
export type ReadResult =
  | ({ isRead: true; model: string; tokens: number } & BuiltDrafts)
  | { isRead: false; failures: string[] };

type ReadOptions = {
  transcript: string;
  inputId: string | null;
  todayBusinessDate: string;
};

export async function readVoiceTranscript(options: ReadOptions): Promise<ReadResult> {
  const reply = await callModel(
    { systemPrompt: VOICE_SYSTEM_PROMPT, userText: options.transcript },
    validateHeardLines,
  );
  if (!reply.isRead) {
    return reply;
  }
  const built = buildDrafts({
    heardLines: reply.data,
    source: "VOICE",
    inputId: options.inputId,
    todayBusinessDate: options.todayBusinessDate,
  });
  return { isRead: true, model: reply.model, tokens: reply.tokens, ...built };
}

type PhotoOptions = {
  // A receipt or nota is PHOTO, a handwritten page is NOTEBOOK.
  source: "PHOTO" | "NOTEBOOK";
  image: AiImage;
  inputId: string | null;
  todayBusinessDate: string;
};

// Spec §9 "Read photo" and "Read notebook page". The page's date, seller and
// printed total come from the image, so the model is told today's date to fill
// in a year the page leaves out.
export async function readPhoto(options: PhotoOptions): Promise<ReadResult> {
  const systemPrompt = options.source === "PHOTO" ? RECEIPT_SYSTEM_PROMPT : NOTEBOOK_SYSTEM_PROMPT;
  const reply = await callModel(
    { systemPrompt, userText: `Hari ini: ${options.todayBusinessDate}. Baca gambar ini.`, image: options.image },
    validateHeardPage,
  );
  if (!reply.isRead) {
    return reply;
  }
  const { lines, seller, date, totalText } = reply.data;
  const built = buildDrafts({
    heardLines: lines,
    source: options.source,
    inputId: options.inputId,
    todayBusinessDate: options.todayBusinessDate,
    document: { seller, date, totalText },
  });
  return { isRead: true, model: reply.model, tokens: reply.tokens, ...built };
}

export type PriceListReadResult =
  | ({ isRead: true; model: string; tokens: number } & PriceListResult)
  | { isRead: false; failures: string[] };

// Spec §9 "Read price list": the items go to POST /items, not to a transaction.
export async function readPriceList(options: { image: AiImage }): Promise<PriceListReadResult> {
  const reply = await callModel(
    { systemPrompt: PRICE_LIST_SYSTEM_PROMPT, userText: "Baca daftar harga ini.", image: options.image },
    validateHeardPriceList,
  );
  if (!reply.isRead) {
    return reply;
  }
  return { isRead: true, model: reply.model, tokens: reply.tokens, ...buildPriceList(reply.data) };
}
