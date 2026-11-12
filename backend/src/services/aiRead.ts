import { callModel } from "../ai/provider.js";
import { VOICE_SYSTEM_PROMPT, validateHeardLines } from "../ai/readPrompt.js";
import { buildDrafts, type BuiltDrafts } from "./draftBuilder.js";

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
