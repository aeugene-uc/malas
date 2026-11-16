import { readFile } from "node:fs/promises";
import { setTimeout as wait } from "node:timers/promises";
import { config } from "../../src/config.js";
import { readVoiceTranscript } from "../../src/services/aiRead.js";
import { savedItemKey, type Draft, type DraftLine, type SavedRecords } from "../../src/services/draftBuilder.js";
import { normaliseName } from "../../src/services/normaliseName.js";
import type { Unit } from "../../src/services/numberWords.js";

// S15 (#15): the AI test set, read live through the real model and scored by
// spec §2's bar: at least 90% of lines fully correct (item, quantity, amount).
// Run with `npm run eval:ai`, or `npm run eval:ai -- 3` to read every case three
// times, since the model does not answer the same way every time. It needs
// GEMMA_API_KEY in backend/.env. It is not a *.test.ts, because it calls the
// model and gives a score rather than a pass or fail.

type Direction = "IN" | "OUT";
type ExpectedLine = { names: string[] | null; quantity: string | null; lineTotal: number | null };
type ExpectedDraft = {
  direction: Direction;
  paid: "full" | number;
  person?: string;
  businessDate?: string;
  dueDate?: string;
  lines: ExpectedLine[];
};
type SavedSeed = { items: { direction: Direction; name: string; price: number; unit?: Unit }[]; people?: string[] };
type VoiceCase = { id: string; note: string; transcript: string; saved?: SavedSeed; drafts: ExpectedDraft[] };
type VoiceSet = { today: string; cases: VoiceCase[] };
type CaseScore = { lineCount: number; correctLines: number; extraLines: number; draftChecks: number; passedDraftChecks: number; problems: string[] };

// The free tier allows about 15 requests a minute.
const PAUSE_BETWEEN_READS_MS = 4_000;
const SPEC_TARGET = 0.9;

const runs = Number(process.argv[2] ?? 1);
if (config.gemmaApiKey === "") {
  throw new Error("GEMMA_API_KEY is not set. Put your AI Studio key in backend/.env.");
}
const voiceSet = JSON.parse(await readFile(new URL("./voice.json", import.meta.url), "utf8")) as VoiceSet;
const total: CaseScore = { lineCount: 0, correctLines: 0, extraLines: 0, draftChecks: 0, passedDraftChecks: 0, problems: [] };
const secondsPerRead: number[] = [];
let failedReads = 0;

for (let run = 1; run <= runs; run++) {
  for (const voiceCase of voiceSet.cases) {
    const startedAt = Date.now();
    const result = await readVoiceTranscript({
      transcript: voiceCase.transcript,
      inputId: null,
      todayBusinessDate: voiceSet.today,
      saved: toSavedRecords(voiceCase.saved),
    });
    const seconds = (Date.now() - startedAt) / 1000;
    secondsPerRead.push(seconds);
    const label = `${voiceCase.id} run ${run}`;
    if (!result.isRead) {
      failedReads++;
      total.lineCount += voiceCase.drafts.flatMap((draft) => draft.lines).length;
      console.log(`✖ ${label}  read failed after ${seconds.toFixed(1)} s: ${result.failures.join("; ")}`);
      await wait(PAUSE_BETWEEN_READS_MS);
      continue;
    }
    const score = scoreCase(voiceCase, result.drafts);
    addScore(total, score);
    const isPerfect = score.correctLines === score.lineCount && score.extraLines === 0 && score.passedDraftChecks === score.draftChecks;
    console.log(`${isPerfect ? "✔" : "✖"} ${label}  ${score.correctLines}/${score.lineCount} lines, ${seconds.toFixed(1)} s  ${voiceCase.note}`);
    for (const problem of score.problems) {
      console.log(`    ${problem}`);
    }
    await wait(PAUSE_BETWEEN_READS_MS);
  }
}

const lineShare = total.correctLines / total.lineCount;
const sortedSeconds = [...secondsPerRead].sort((a, b) => a - b);
console.log("");
console.log(`Lines fully correct: ${total.correctLines}/${total.lineCount} (${(lineShare * 100).toFixed(1)}%), spec §2 needs ${SPEC_TARGET * 100}%`);
console.log(`Extra lines: ${total.extraLines}`);
console.log(`Draft fields (paid, person, date, due date): ${total.passedDraftChecks}/${total.draftChecks}`);
console.log(`Failed reads: ${failedReads} of ${secondsPerRead.length}`);
console.log(`Seconds per read: median ${(sortedSeconds[Math.floor(sortedSeconds.length / 2)] ?? 0).toFixed(1)}, slowest ${(sortedSeconds.at(-1) ?? 0).toFixed(1)}`);

// Each expected line is matched to one line the read produced, in the same
// direction and with a matching name. It is fully correct when its quantity and
// line total are both right. Lines the read made that match nothing are extra.
function scoreCase(voiceCase: VoiceCase, drafts: Draft[]): CaseScore {
  const score: CaseScore = { lineCount: 0, correctLines: 0, extraLines: 0, draftChecks: 0, passedDraftChecks: 0, problems: [] };
  const actualLines = drafts.flatMap((draft) => draft.lines.map((line) => ({ line, draft, isUsed: false })));
  for (const expectedDraft of voiceCase.drafts) {
    let matchedDraft: Draft | null = null;
    for (const expectedLine of expectedDraft.lines) {
      score.lineCount++;
      const sameDirection = actualLines.filter((actual) => !actual.isUsed && actual.draft.direction === expectedDraft.direction);
      const match =
        expectedLine.names === null
          ? (sameDirection.find((actual) => actual.line.lineTotal === expectedLine.lineTotal) ?? sameDirection[0])
          : sameDirection.find((actual) => isNameMatch(expectedLine.names ?? [], actual.line));
      const name = expectedLine.names?.[0] ?? `${expectedDraft.direction} ${expectedLine.lineTotal}`;
      if (match === undefined) {
        score.problems.push(`${name}: no matching line`);
        continue;
      }
      match.isUsed = true;
      matchedDraft ??= match.draft;
      const lineProblems = compareLine(expectedLine, match.line);
      if (lineProblems.length === 0) {
        score.correctLines++;
      }
      score.problems.push(...lineProblems.map((problem) => `${name}: ${problem}`));
    }
    score.draftChecks += countDraftChecks(expectedDraft);
    if (matchedDraft !== null) {
      const draftProblems = compareDraft(expectedDraft, matchedDraft);
      score.passedDraftChecks += countDraftChecks(expectedDraft) - draftProblems.length;
      score.problems.push(...draftProblems.map((problem) => `${expectedDraft.direction} draft: ${problem}`));
    }
  }
  for (const extra of actualLines.filter((actual) => !actual.isUsed)) {
    score.extraLines++;
    score.problems.push(`extra line: ${extra.draft.direction} ${extra.line.itemName ?? "(no name)"} ${extra.line.quantity ?? "-"} ${extra.line.lineTotal ?? "-"}`);
  }
  return score;
}

function isNameMatch(names: string[], line: DraftLine): boolean {
  if (line.itemName === null) {
    return false;
  }
  const heard = normaliseName(line.itemName);
  return names.map(normaliseName).some((name) => heard === name || heard.includes(name) || name.includes(heard));
}

function compareLine(expected: ExpectedLine, actual: DraftLine): string[] {
  const problems: string[] = [];
  if (actual.quantity !== expected.quantity) {
    problems.push(`quantity ${JSON.stringify(actual.quantity)}, expected ${JSON.stringify(expected.quantity)}`);
  }
  if (actual.lineTotal !== expected.lineTotal) {
    problems.push(`line total ${actual.lineTotal}, expected ${expected.lineTotal}`);
  }
  return problems;
}

// Paid is always checked; person, business date and due date when the case
// names them. A case without businessDate expects today, which is left out.
function countDraftChecks(expected: ExpectedDraft): number {
  return 3 + (expected.dueDate === undefined ? 0 : 1);
}

function compareDraft(expected: ExpectedDraft, actual: Draft): string[] {
  const problems: string[] = [];
  const paid = actual.payments.reduce((sum, payment) => sum + payment.amount, 0);
  const expectedPaid = expected.paid === "full" ? actual.total : expected.paid;
  if (paid !== expectedPaid) {
    problems.push(`paid ${paid}, expected ${expected.paid === "full" ? `full (${actual.total})` : expected.paid}`);
  }
  const expectedPerson = expected.person === undefined ? null : normaliseName(expected.person);
  const actualPerson = actual.personName === null ? null : normaliseName(actual.personName);
  if (actualPerson !== expectedPerson) {
    problems.push(`person ${JSON.stringify(actual.personName)}, expected ${JSON.stringify(expected.person ?? null)}`);
  }
  if ((actual.businessDate ?? null) !== (expected.businessDate ?? null)) {
    problems.push(`date ${actual.businessDate ?? "today"}, expected ${expected.businessDate ?? "today"}`);
  }
  if (expected.dueDate !== undefined && actual.dueDate !== expected.dueDate) {
    problems.push(`due ${actual.dueDate}, expected ${expected.dueDate}`);
  }
  return problems;
}

function addScore(sum: CaseScore, score: CaseScore): void {
  sum.lineCount += score.lineCount;
  sum.correctLines += score.correctLines;
  sum.extraLines += score.extraLines;
  sum.draftChecks += score.draftChecks;
  sum.passedDraftChecks += score.passedDraftChecks;
}

function toSavedRecords(seed: SavedSeed | undefined): SavedRecords {
  const itemsByKey = new Map(
    (seed?.items ?? []).map((item, index) => [
      savedItemKey(item.direction, item.name),
      { id: `saved-item-${index}`, categoryId: null, unit: item.unit ?? null, savedPrice: item.price },
    ]),
  );
  const personIdsByName = new Map((seed?.people ?? []).map((name, index) => [normaliseName(name), `saved-person-${index}`]));
  return { itemsByKey, personIdsByName };
}
