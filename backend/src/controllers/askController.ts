import { readAuth } from "../auth.js";
import { handleAsync } from "../errors.js";
import * as askService from "../services/askService.js";
import { readBody, throwIfInvalid, type FieldErrors } from "./validate.js";

// POST /ai/ask {question, previousQuestion?}, as F8 sends it (#183).

const MAX_QUESTION_LENGTH = 300;

export const ask = handleAsync(async (req, res) => {
  const input = readAskBody(readBody(req));
  res.json(await askService.askForStore(readAuth(res).storeId, input));
});

export function readAskBody(body: Record<string, unknown>): { question: string; previousQuestion: string | null } {
  const fields: FieldErrors = {};
  const question = typeof body.question === "string" ? body.question.trim() : "";
  if (question === "" || question.length > MAX_QUESTION_LENGTH) {
    fields.question = "Tulis pertanyaan";
  }
  const previous = body.previousQuestion ?? null;
  const previousQuestion = typeof previous === "string" ? previous.trim().slice(0, MAX_QUESTION_LENGTH) || null : null;
  if (previous !== null && typeof previous !== "string") {
    fields.previousQuestion = "Pertanyaan sebelumnya tidak valid";
  }
  throwIfInvalid(fields);
  return { question, previousQuestion };
}
