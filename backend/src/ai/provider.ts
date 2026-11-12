import { config } from "../config.js";

// Spec §13 and risk 6: every model call goes through this one function, so
// switching provider or model is a change here and nowhere else.

export type AiImage = { mimeType: "image/jpeg" | "image/png" | "image/webp"; base64: string };

export type AiRequest = {
  systemPrompt: string;
  userText: string;
  image?: AiImage;
};

export type AiResult<T> =
  | { isRead: true; data: T; model: string; tokens: number }
  | { isRead: false; failures: string[] };

// Google AI Studio's native API. Its OpenAI-compatible route failed every call
// in our test (#122), while this one answered.
const MODEL = "gemma-4-31b-it";
const API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

// Spec §12 says 20 s, but Gemma 4 on the free tier took 38-51 s per read in
// our test. Raised for dev by Eugene's decision in #123; the app shows a
// reading state meanwhile.
export const AI_TIMEOUT_MS = 60_000;
const ATTEMPTS = 2;

// Spec §12: bad JSON or a timeout gets one retry, then an empty draft. A failed
// result tells the caller to return an empty draft and not count the read
// against the plan quota.
export async function callModel<T>(request: AiRequest, validate: (value: unknown) => T): Promise<AiResult<T>> {
  const failures: string[] = [];

  for (let attempt = 1; attempt <= ATTEMPTS; attempt++) {
    try {
      const reply = await requestCompletion(request);
      return { isRead: true, data: validate(parseModelJson(reply.text)), model: MODEL, tokens: reply.tokens };
    } catch (error) {
      failures.push(`attempt ${attempt}: ${describeError(error)}`);
    }
  }
  console.warn("AI read failed after retry", failures);
  return { isRead: false, failures };
}

async function requestCompletion(request: AiRequest): Promise<{ text: string; tokens: number }> {
  if (config.gemmaApiKey === "") {
    throw new Error("GEMMA_API_KEY is not set. Add it to backend/.env.");
  }
  const response = await fetch(API_URL, {
    method: "POST",
    headers: { "x-goog-api-key": config.gemmaApiKey, "Content-Type": "application/json" },
    body: JSON.stringify({
      system_instruction: { parts: [{ text: request.systemPrompt }] },
      contents: [{ role: "user", parts: buildUserParts(request) }],
      generationConfig: { temperature: 0 },
    }),
    signal: AbortSignal.timeout(AI_TIMEOUT_MS),
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return readCompletion(await response.json());
}

// The model card puts the image before the text.
function buildUserParts(request: AiRequest): unknown[] {
  const textPart = { text: request.userText };
  if (request.image === undefined) {
    return [textPart];
  }
  return [{ inline_data: { mime_type: request.image.mimeType, data: request.image.base64 } }, textPart];
}

type GeminiPart = { text?: unknown; thought?: unknown };

// The provider's response is a network boundary, so its shape is checked
// rather than trusted. Gemma 4 always thinks first and the API returns that
// reasoning as parts marked `thought`, which are not the answer.
function readCompletion(body: unknown): { text: string; tokens: number } {
  const completion = body as {
    candidates?: { content?: { parts?: GeminiPart[] } }[];
    usageMetadata?: { totalTokenCount?: unknown };
  };
  const parts = completion.candidates?.[0]?.content?.parts ?? [];
  const answerTexts = parts
    .filter((part) => part.thought !== true)
    .map((part) => part.text)
    .filter((text): text is string => typeof text === "string");
  if (answerTexts.length === 0) {
    throw new Error("response has no answer text");
  }
  const tokens = completion.usageMetadata?.totalTokenCount;
  return { text: answerTexts.join(""), tokens: typeof tokens === "number" ? tokens : 0 };
}

// Gemma has no JSON mode on this API, so replies come wrapped in a ```json
// fence.
function parseModelJson(content: string): unknown {
  const unfenced = content
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "");
  return JSON.parse(unfenced);
}

function describeError(error: unknown): string {
  if (error instanceof Error && error.name === "TimeoutError") {
    return `no reply within ${AI_TIMEOUT_MS / 1000} s`;
  }
  return error instanceof Error ? error.message : String(error);
}
