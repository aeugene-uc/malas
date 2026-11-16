import { createHash } from "node:crypto";
import { Prisma, type Category, type Item } from "@prisma/client";
import { prisma } from "../db.js";
import { ApiError } from "../errors.js";
import { buildWarning, type Warning } from "../warnings.js";
import { resolveBusinessDate } from "./businessDate.js";
import { normaliseName } from "./normaliseName.js";
import * as saveRules from "./saveRules.js";
import { TRANSACTION_ROW_SELECT, toTransactionRow, type TransactionRow } from "./transactionRows.js";

// Simpan (spec §7.3, contract "Transactions — the save path"). Code resolves
// names, recomputes every number (§5.1), flags what is unclear without blocking
// (§5.4) and makes a retried save replay instead of recording twice.

export type Direction = "IN" | "OUT";
export type Source = "TYPED" | "VOICE" | "PHOTO" | "NOTEBOOK";

export type SaveLine = {
  itemId: string | null;
  itemName: string | null;
  categoryId: string | null;
  quantity: string | null;
  unit: string | null;
  unitPrice: number | null;
  lineTotal: number | null;
};

export type SavePayment = { date: string; amount: number; label: string | null };

export type SaveRequest = {
  businessDate: string | null;
  direction: Direction;
  total: number | null;
  personId: string | null;
  personName: string | null;
  dueDate: string | null;
  source: Source;
  inputId: string | null;
  linkedTransactionId: string | null;
  note: string | null;
  lines: SaveLine[];
  payments: SavePayment[];
};

export type SavedLineRow = TransactionRow["lines"][number] & { isNew: boolean };
export type SaveResponse = { transaction: Omit<TransactionRow, "lines"> & { lines: SavedLineRow[] }; warnings: Warning[] };

type Tx = Prisma.TransactionClient;

// The category a line gets when neither the owner nor its item chose one
// (spec §4.2's fixed list).
const DEFAULT_CATEGORY_BY_DIRECTION: Record<Direction, string> = { IN: "Penjualan", OUT: "Lainnya" };

export async function save(options: { storeId: string; request: SaveRequest; idempotencyKey: string }): Promise<SaveResponse> {
  const { storeId, request, idempotencyKey } = options;
  const requestHash = createHash("sha256").update(JSON.stringify(request)).digest("hex");
  const replayed = await findReplay({ storeId, idempotencyKey, requestHash });
  if (replayed !== null) {
    return replayed;
  }
  try {
    return await prisma.$transaction(async (tx) => {
      const response = await writeTransaction(tx, storeId, request);
      await tx.idempotencyKey.create({ data: { storeId, key: idempotencyKey, requestHash, response: response as unknown as Prisma.InputJsonValue } });
      return response;
    });
  } catch (error) {
    // Two sends of the same draft at once: the second loses on the unique key
    // and its whole write rolls back, so it answers with the first one's save.
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      const winner = await findReplay({ storeId, idempotencyKey, requestHash });
      if (winner !== null) {
        return winner;
      }
    }
    throw error;
  }
}

async function findReplay(options: { storeId: string; idempotencyKey: string; requestHash: string }): Promise<SaveResponse | null> {
  const stored = await prisma.idempotencyKey.findUnique({ where: { storeId_key: { storeId: options.storeId, key: options.idempotencyKey } } });
  if (stored === null) {
    return null;
  }
  if (stored.requestHash !== options.requestHash) {
    throw new ApiError({ code: "IDEMPOTENCY_CONFLICT", message: "Catatan ini sudah disimpan dengan isi lain" });
  }
  return stored.response as unknown as SaveResponse;
}

type PendingLine = {
  itemId: string | null;
  categoryId: string;
  quantity: string | null;
  unit: string | null;
  unitPrice: number | null;
  lineTotal: number;
  discount: number;
  isNew: boolean;
  warningCodes: ("PRICE_IMPLAUSIBLE" | "ITEM_NO_PRICE")[];
};

async function writeTransaction(tx: Tx, storeId: string, request: SaveRequest): Promise<SaveResponse> {
  const store = await tx.store.findUniqueOrThrow({ where: { id: storeId } });
  const today = resolveBusinessDate({ now: new Date(), timezone: store.timezone, dayChangeHour: store.dayChangeHour });
  const businessDate = request.businessDate ?? today;
  if (businessDate > today) {
    throw new ApiError({ code: "VALIDATION_FAILED", message: "Tanggal belum lewat", fields: { businessDate: "Tanggal belum lewat" } });
  }
  await requireOwnedLinks(tx, storeId, request);
  const personId = await resolvePerson(tx, storeId, request);
  const categories = await tx.category.findMany({ where: { storeId } });
  const defaultCategoryId = findDefaultCategory(categories, request.direction).id;

  const pendingLines: PendingLine[] = [];
  for (const [index, line] of request.lines.entries()) {
    pendingLines.push(await resolveLine(tx, { storeId, direction: request.direction, line, index, categories, defaultCategoryId }));
  }

  // The app keeps `total` equal to the line totals it knows, so a line whose
  // price only the server filled in adds to the total rather than becoming a
  // gap (#260: unknown prices travel as null).
  const knownLineSum = saveRules.sumLineTotals(request.lines.map((line) => ({ lineTotal: line.lineTotal ?? 0 })));
  const serverFilledSum = saveRules.sumLineTotals(pendingLines.filter((_, index) => request.lines[index]?.lineTotal === null));
  const total = (request.total ?? knownLineSum) + serverFilledSum;
  const settled = saveRules.settleTotalGap(pendingLines, total);
  const linesToSave = settled.lines;
  if (settled.extraLineTotal !== null) {
    linesToSave.push({ itemId: null, categoryId: defaultCategoryId, quantity: null, unit: null, unitPrice: null, lineTotal: settled.extraLineTotal, discount: 0, isNew: false, warningCodes: [] });
  }

  const duplicateId = await findDuplicate(tx, { storeId, request, businessDate, total });
  const isSale = request.direction === "IN" && linesToSave.some((line) => categories.find((category) => category.id === line.categoryId)?.countedInProfit === true);
  const isLumpSumMix = isSale && (await mixesLumpSumAndItemised(tx, { storeId, businessDate, isItemised: linesToSave.some((line) => line.itemId !== null) }));

  const created = await tx.transaction.create({
    data: {
      storeId,
      businessDate: toDbDate(businessDate),
      direction: request.direction,
      total,
      personId,
      dueDate: request.dueDate === null ? null : toDbDate(request.dueDate),
      linkedTransactionId: request.linkedTransactionId,
      source: request.source,
      inputId: request.inputId,
      note: request.note,
      payments: { create: request.payments.map((payment) => ({ date: toDbDate(payment.date), amount: payment.amount, label: payment.label })) },
    },
  });

  const warnings: Warning[] = [];
  const newLineIds = new Set<string>();
  for (const line of linesToSave) {
    const { id } = await tx.line.create({
      data: { transactionId: created.id, itemId: line.itemId, categoryId: line.categoryId, quantity: line.quantity, unit: line.unit, unitPrice: line.unitPrice, lineTotal: line.lineTotal, discount: line.discount },
    });
    if (line.isNew) newLineIds.add(id);
    warnings.push(...line.warningCodes.map((code) => buildWarning(code, { lineId: id })));
  }
  if (request.lines.length > 0 && total !== saveRules.sumLineTotals(pendingLines)) {
    warnings.push(buildWarning("TOTAL_MISMATCH", { transactionId: created.id }));
  }
  if (duplicateId !== null) warnings.push(buildWarning("DUPLICATE_SUSPECTED", { transactionId: duplicateId }));
  if (isLumpSumMix) warnings.push(buildWarning("LUMP_SUM_WITH_ITEMISED", { transactionId: created.id }));
  if (saveRules.isOverpaid(total, request.payments)) warnings.push(buildWarning("OVERPAID", { transactionId: created.id }));

  const row = toTransactionRow(await tx.transaction.findUniqueOrThrow({ where: { id: created.id }, select: TRANSACTION_ROW_SELECT }));
  return { transaction: { ...row, lines: row.lines.map((line) => ({ ...line, isNew: newLineIds.has(line.id) })) }, warnings };
}

// ---- Lines ------------------------------------------------------------------

async function resolveLine(
  tx: Tx,
  options: { storeId: string; direction: Direction; line: SaveLine; index: number; categories: Category[]; defaultCategoryId: string },
): Promise<PendingLine> {
  const { storeId, direction, line, index } = options;
  const chosenCategoryId = requireCategory(options.categories, { categoryId: line.categoryId, direction, field: `lines.${index}.categoryId` });
  const kind = direction === "IN" ? "SOLD" : "BOUGHT";
  const found = await findItem(tx, { storeId, kind, line, field: `lines.${index}.itemId` });
  const savedPrice = found?.savedPrice ?? null;
  const money = saveRules.computeLineMoney(line, savedPrice);
  const categoryId = chosenCategoryId ?? found?.categoryId ?? options.defaultCategoryId;
  const isImplausible = line.unitPrice !== null && saveRules.isPriceImplausible(line.unitPrice, savedPrice);

  let item: Item | null = found;
  let isNew = false;
  if (item === null && line.itemName !== null) {
    // §7.3: a new item is created on save and marked Baru.
    item = await tx.item.create({
      data: { storeId, name: line.itemName, normalisedName: normaliseName(line.itemName), kind, categoryId, savedPrice: money.unitPrice, unit: line.unit },
    });
    isNew = true;
  } else if (item !== null && !isImplausible) {
    await rememberLastPrice(tx, { item, line });
  }

  const warningCodes: PendingLine["warningCodes"] = [];
  if (isImplausible) warningCodes.push("PRICE_IMPLAUSIBLE");
  if (money.hasNoPrice || (item !== null && money.unitPrice === null && item.savedPrice === null)) warningCodes.push("ITEM_NO_PRICE");
  return { itemId: item?.id ?? null, categoryId, quantity: line.quantity, unit: line.unit ?? item?.unit ?? null, unitPrice: money.unitPrice, lineTotal: money.lineTotal, discount: money.discount, isNew, warningCodes };
}

// An item id must be this store's and point the same way. A name with no id is
// matched silently on its normalised form (§7.3: no merge question).
async function findItem(tx: Tx, options: { storeId: string; kind: "SOLD" | "BOUGHT"; line: SaveLine; field: string }): Promise<Item | null> {
  const { storeId, kind, line } = options;
  if (line.itemId !== null) {
    const item = await tx.item.findFirst({ where: { id: line.itemId, storeId, kind } });
    if (item === null) {
      throw new ApiError({ code: "VALIDATION_FAILED", message: "Barang tidak ditemukan", fields: { [options.field]: "Barang tidak ditemukan" } });
    }
    return item;
  }
  if (line.itemName === null) {
    return null;
  }
  return tx.item.findUnique({ where: { storeId_normalisedName_kind: { storeId, normalisedName: normaliseName(line.itemName), kind } } });
}

// §7.3: an item's saved price becomes the last price used. A retur's price is
// the old one, so it changes nothing.
async function rememberLastPrice(tx: Tx, options: { item: Item; line: SaveLine }): Promise<void> {
  const { item, line } = options;
  const isRetur = line.quantity !== null && line.quantity.startsWith("-");
  const changes: Prisma.ItemUpdateInput = {};
  if (line.unitPrice !== null && line.unitPrice > 0 && !isRetur && line.unitPrice !== item.savedPrice) changes.savedPrice = line.unitPrice;
  if (item.unit === null && line.unit !== null) changes.unit = line.unit;
  if (Object.keys(changes).length > 0) {
    await tx.item.update({ where: { id: item.id }, data: changes });
  }
}

function requireCategory(categories: Category[], options: { categoryId: string | null; direction: Direction; field: string }): string | null {
  if (options.categoryId === null) {
    return null;
  }
  const category = categories.find((candidate) => candidate.id === options.categoryId);
  if (category === undefined || category.direction !== options.direction) {
    throw new ApiError({ code: "VALIDATION_FAILED", message: "Kategori tidak cocok", fields: { [options.field]: "Kategori tidak cocok" } });
  }
  return category.id;
}

function findDefaultCategory(categories: Category[], direction: Direction): Category {
  const name = DEFAULT_CATEGORY_BY_DIRECTION[direction];
  const category = categories.find((candidate) => candidate.fixed && candidate.direction === direction && candidate.name === name);
  if (category === undefined) {
    // Every store is created with the fixed categories (S4), so this is a bug.
    throw new Error(`Store has no fixed category ${name}`);
  }
  return category;
}

// ---- Person and links -------------------------------------------------------

// §7.3: names are matched by code. An unknown name becomes a new person.
async function resolvePerson(tx: Tx, storeId: string, request: SaveRequest): Promise<string | null> {
  if (request.personId !== null) {
    const person = await tx.person.findFirst({ where: { id: request.personId, storeId } });
    if (person === null) {
      throw new ApiError({ code: "VALIDATION_FAILED", message: "Orang tidak ditemukan", fields: { personId: "Orang tidak ditemukan" } });
    }
    return person.id;
  }
  if (request.personName === null) {
    return null;
  }
  const wantedName = normaliseName(request.personName);
  const people = await tx.person.findMany({ where: { storeId }, select: { id: true, name: true } });
  const match = people.find((person) => normaliseName(person.name) === wantedName);
  return match?.id ?? (await tx.person.create({ data: { storeId, name: request.personName } })).id;
}

async function requireOwnedLinks(tx: Tx, storeId: string, request: SaveRequest): Promise<void> {
  if (request.inputId !== null && (await tx.input.findFirst({ where: { id: request.inputId, storeId } })) === null) {
    throw new ApiError({ code: "VALIDATION_FAILED", message: "Bacaan tidak ditemukan", fields: { inputId: "Bacaan tidak ditemukan" } });
  }
  if (request.linkedTransactionId !== null && (await tx.transaction.findFirst({ where: { id: request.linkedTransactionId, storeId, deletedAt: null } })) === null) {
    throw new ApiError({ code: "VALIDATION_FAILED", message: "Catatan asal tidak ditemukan", fields: { linkedTransactionId: "Catatan asal tidak ditemukan" } });
  }
}

// ---- Soft warnings ----------------------------------------------------------

// §7.3: the same photo twice, or the same date, direction and total as an
// entry already saved (a sale spoken and then photographed).
async function findDuplicate(tx: Tx, options: { storeId: string; request: SaveRequest; businessDate: string; total: number }): Promise<string | null> {
  const { storeId, request } = options;
  const sameEntry = await tx.transaction.findFirst({
    where: { storeId, deletedAt: null, businessDate: toDbDate(options.businessDate), direction: request.direction, total: options.total },
    select: { id: true },
  });
  if (sameEntry !== null) {
    return sameEntry.id;
  }
  if (request.inputId === null) {
    return null;
  }
  const input = await tx.input.findUniqueOrThrow({ where: { id: request.inputId }, select: { imageHash: true } });
  if (input.imageHash === null) {
    return null;
  }
  const samePhoto = await tx.transaction.findFirst({
    where: { storeId, deletedAt: null, inputId: { not: request.inputId }, input: { imageHash: input.imageHash } },
    select: { id: true },
  });
  return samePhoto?.id ?? null;
}

// §12: "Sudah ada penjualan rinci hari ini" before a lump sum, and the reverse.
async function mixesLumpSumAndItemised(tx: Tx, options: { storeId: string; businessDate: string; isItemised: boolean }): Promise<boolean> {
  const sameDaySales = await tx.transaction.findMany({
    where: { storeId: options.storeId, deletedAt: null, direction: "IN", businessDate: toDbDate(options.businessDate), lines: { some: { category: { countedInProfit: true } } } },
    select: { lines: { select: { itemId: true } } },
  });
  return saveRules.mixesLumpSumAndItemised({
    isItemised: options.isItemised,
    sameDaySales: sameDaySales.map((sale) => ({ isItemised: sale.lines.some((line) => line.itemId !== null) })),
  });
}

// A business date is a calendar day, stored as that day at UTC midnight.
function toDbDate(date: string): Date {
  return new Date(`${date}T00:00:00Z`);
}

// ---- Delete and Batal -------------------------------------------------------

// §7.5: delete is soft, and the payments go with it because every query skips
// a deleted transaction's payments. Batal on the toast is the restore.
export async function deleteTransaction(storeId: string, transactionId: string): Promise<void> {
  await setDeletedAt({ storeId, transactionId, deletedAt: new Date() });
}

export async function restoreTransaction(storeId: string, transactionId: string): Promise<void> {
  await setDeletedAt({ storeId, transactionId, deletedAt: null });
}

async function setDeletedAt(options: { storeId: string; transactionId: string; deletedAt: Date | null }): Promise<void> {
  const { count } = await prisma.transaction.updateMany({ where: { id: options.transactionId, storeId: options.storeId }, data: { deletedAt: options.deletedAt } });
  if (count === 0) {
    throw new ApiError({ code: "NOT_FOUND", message: "Catatan tidak ditemukan" });
  }
}
