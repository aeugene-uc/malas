import { config } from "../config.js";

// Spec §13 and risk 6: every model call goes through this one function, so
// switching provider is a change here and nowhere else.

export type ModelId = "google/gemma-4-31b-it" | "deepseek-ai/deepseek-v4.1-flash";

export type AiImage = { mimeType: "image/jpeg" | "image/png" | "image/webp"; base64: string };

export type AiRequest = {
  systemPrompt: string;
  userText: string;
  image?: AiImage;
};

export type AiResult<T> =
  | { isRead: true; data: T; model: ModelId; tokens: number }
  | { isRead: false; failures: string[] };

const NVIDIA_URL = "https://integrate.api.nvidia.com/v1/chat/completions";
const GEMMA: ModelId = "google/gemma-4-31b-it";
const DEEPSEEK: ModelId = "deepseek-ai/deepseek-v4.1-flash";

// Spec §12: bad JSON or over 20 seconds gets one retry, then an empty draft.
const TIMEOUT_MS = 20_000;

// Two attempts in total. The retry goes to DeepSeek, unless there is an image,
// which only Gemma reads. A failed result tells the caller to return an empty
// draft and not count the read against the plan quota.
export async function callModel<T>(request: AiRequest, validate: (value: unknown) => T): Promise<AiResult<T>> {
  const retryModel = request.image === undefined ? DEEPSEEK : GEMMA;
  const failures: string[] = [];

  for (const model of [GEMMA, retryModel]) {
    try {
      const reply = await requestCompletion(model, request);
      return { isRead: true, data: validate(parseModelJson(reply.content)), model, tokens: reply.tokens };
    } catch (error) {
      failures.push(`${model}: ${describeError(error)}`);
    }
  }
  console.warn("AI read failed after retry", failures);
  return { isRead: false, failures };
}

async function requestCompletion(model: ModelId, request: AiRequest): Promise<{ content: string; tokens: number }> {
  if (config.nvidiaApiKey === "") {
    throw new Error("NVIDIA_API_KEY is not set. Add it to backend/.env.");
  }
  const response = await fetch(NVIDIA_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${config.nvidiaApiKey}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({ model, messages: buildMessages(request), temperature: 0 }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return readCompletion(await response.json());
}

// The model card puts the image before the text.
function buildMessages(request: AiRequest): unknown[] {
  const userContent =
    request.image === undefined
      ? request.userText
      : [
          {
            type: "image_url",
            image_url: { url: `data:${request.image.mimeType};base64,${request.image.base64}` },
          },
          { type: "text", text: request.userText },
        ];
  return [
    { role: "system", content: request.systemPrompt },
    { role: "user", content: userContent },
  ];
}

// The provider's response is a network boundary, so its shape is checked
// rather than trusted.
function readCompletion(body: unknown): { content: string; tokens: number } {
  const completion = body as {
    choices?: { message?: { content?: unknown } }[];
    usage?: { total_tokens?: unknown };
  };
  const content = completion.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    throw new Error("response has no message content");
  }
  const tokens = completion.usage?.total_tokens;
  return { content, tokens: typeof tokens === "number" ? tokens : 0 };
}

// Gemma on NVIDIA has no JSON mode, so replies sometimes come wrapped in a
// ```json fence.
function parseModelJson(content: string): unknown {
  const unfenced = content
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "");
  return JSON.parse(unfenced);
}

function describeError(error: unknown): string {
  if (error instanceof Error && error.name === "TimeoutError") {
    return `no reply within ${TIMEOUT_MS / 1000} s`;
  }
  return error instanceof Error ? error.message : String(error);
}
