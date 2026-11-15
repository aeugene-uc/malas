import { prisma } from "../db.js";
import { ApiError } from "../errors.js";
import { hasQuestionsLeft, isNewMonth, isTanyaAvailable } from "./aiQuota.js";
import { resolveBusinessDate } from "./businessDate.js";
import { askTanya, type TanyaAnswer } from "./tanya.js";
import { StoreQueries } from "./tanyaQueries.js";

// POST /ai/ask for one store (spec §7.8, §18): Pro only after the trial, a
// monthly limit, and a question counted only when it was answered.

export async function askForStore(storeId: string, input: { question: string; previousQuestion: string | null }): Promise<TanyaAnswer> {
  const now = new Date();
  const store = await prisma.store.findUniqueOrThrow({ where: { id: storeId } });
  if (!isTanyaAvailable(store, now)) {
    throw new ApiError({ code: "PLAN_REQUIRED", message: "Tanya ada di paket Pro" });
  }
  if (!hasQuestionsLeft(store, now)) {
    throw new ApiError({ code: "PLAN_LIMIT_REACHED", message: "Jatah pertanyaan bulan ini sudah habis" });
  }
  const closedDays = Array.isArray(store.closedDays) ? store.closedDays.filter((day): day is number => typeof day === "number") : [];
  const result = await askTanya({
    question: input.question,
    previousQuestion: input.previousQuestion,
    todayBusinessDate: resolveBusinessDate({ now, timezone: store.timezone, dayChangeHour: store.dayChangeHour }),
    queries: new StoreQueries(storeId, closedDays),
  });
  if (!result.isAnswered) {
    throw new ApiError({ code: "AI_READ_FAILED", message: "Belum bisa menjawab. Coba lagi." });
  }
  await prisma.store.update({
    where: { id: storeId },
    data: isNewMonth(store.questionsResetAt, store.timezone, now)
      ? { questionsThisMonth: 1, questionsResetAt: now }
      : { questionsThisMonth: { increment: 1 } },
  });
  return { answer: result.answer, figures: result.figures, daysRecorded: result.daysRecorded, period: result.period, function: result.function };
}
