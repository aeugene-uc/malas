import type { Request } from "express";
import { readAuth } from "../auth.js";
import { ApiError, handleAsync } from "../errors.js";
import * as transactionService from "../services/transactionService.js";
import type { SaveLine, SavePayment, SaveRequest, Source } from "../services/transactionService.js";
import { readBody, readPrice, throwIfInvalid, type FieldErrors } from "./validate.js";

// Simpan (contract "Transactions — the save path"). The body is the draft the
// AI read returned, edited by the owner. Spec §5.4: only a malformed body is
// refused; everything unclear is saved and flagged.

const SOURCES: Source[] = ["TYPED", "VOICE", "PHOTO", "NOTEBOOK"];
const DATE = /^\d{4}-\d{2}-\d{2}$/;
// Up to 3 decimals, like Line.quantity. A retur is negative (spec §4.2).
const QUANTITY = /^-?\d{1,6}(\.\d{1,3})?$/;
// Rp 1 triliun: far above any micro business, low enough that sums stay exact.
const MAX_MONEY = 1_000_000_000_000;
const MAX_LINES = 100;
const MAX_PAYMENTS = 20;
const MAX_KEY_LENGTH = 100;

export const saveTransaction = handleAsync(async (req, res) => {
  const idempotencyKey = readIdempotencyKey(req);
  const request = readSaveRequest(readBody(req));
  const saved = await transactionService.save({ storeId: readAuth(res).storeId, request, idempotencyKey });
  res.status(201).json(saved);
});

// One UUID per draft, reused on every retry (contract, agreed in #54).
function readIdempotencyKey(req: Request): string {
  const key = (req.get("Idempotency-Key") ?? "").trim();
  if (key === "" || key.length > MAX_KEY_LENGTH) {
    throw new ApiError({ code: "VALIDATION_FAILED", message: "Idempotency-Key wajib", fields: { idempotencyKey: "Idempotency-Key wajib" } });
  }
  return key;
}

export function readSaveRequest(body: Record<string, unknown>): SaveRequest {
  const fields: FieldErrors = {};
  const direction = body.direction === "IN" || body.direction === "OUT" ? body.direction : undefined;
  if (direction === undefined) fields.direction = "Pilih masuk atau keluar";
  const source = body.source === undefined || body.source === null ? "TYPED" : SOURCES.find((candidate) => candidate === body.source);
  if (source === undefined) fields.source = "Sumber tidak dikenal";

  const request = {
    businessDate: readOptionalDate(body.businessDate, "businessDate", fields),
    total: readOptionalMoney(body.total, "total", fields),
    personId: readOptionalId(body.personId, "personId", fields),
    personName: readOptionalText(body.personName, "personName", fields, 80),
    dueDate: readOptionalDate(body.dueDate, "dueDate", fields),
    inputId: readOptionalId(body.inputId, "inputId", fields),
    linkedTransactionId: readOptionalId(body.linkedTransactionId, "linkedTransactionId", fields),
    note: readOptionalText(body.note, "note", fields, 1000),
    lines: readLines(body.lines, fields),
    payments: readPayments(body.payments, fields),
  };
  // The simplest entry is an amount (spec §4.1), but there must be one.
  if (request.lines?.length === 0 && (request.total === null || request.total === undefined)) {
    fields.lines = "Isi jumlah";
  }
  throwIfInvalid(fields);
  return { ...(request as Omit<SaveRequest, "direction" | "source">), direction: direction as SaveRequest["direction"], source: source as Source };
}

function readLines(value: unknown, fields: FieldErrors): SaveLine[] | undefined {
  if (value === undefined || value === null) {
    return [];
  }
  if (!Array.isArray(value) || value.length > MAX_LINES) {
    fields.lines = "Baris tidak valid";
    return undefined;
  }
  return value.map((raw, index) => readLine(raw, `lines.${index}`, fields));
}

function readLine(raw: unknown, prefix: string, fields: FieldErrors): SaveLine {
  const line = typeof raw === "object" && raw !== null ? (raw as Record<string, unknown>) : {};
  if (line !== raw) fields[prefix] = "Baris tidak valid";
  const quantity = line.quantity ?? null;
  if (quantity !== null && (typeof quantity !== "string" || !QUANTITY.test(quantity))) {
    fields[`${prefix}.quantity`] = "Jumlah barang tidak valid";
  }
  return {
    itemId: readOptionalId(line.itemId, `${prefix}.itemId`, fields) ?? null,
    itemName: readOptionalText(line.itemName, `${prefix}.itemName`, fields, 80) ?? null,
    categoryId: readOptionalId(line.categoryId, `${prefix}.categoryId`, fields) ?? null,
    quantity: typeof quantity === "string" ? quantity : null,
    unit: readOptionalText(line.unit, `${prefix}.unit`, fields, 20) ?? null,
    unitPrice: readPrice(line.unitPrice ?? null, `${prefix}.unitPrice`, fields) ?? null,
    lineTotal: readOptionalMoney(line.lineTotal, `${prefix}.lineTotal`, fields) ?? null,
  };
}

function readPayments(value: unknown, fields: FieldErrors): SavePayment[] | undefined {
  if (value === undefined || value === null) {
    return [];
  }
  if (!Array.isArray(value) || value.length > MAX_PAYMENTS) {
    fields.payments = "Pembayaran tidak valid";
    return undefined;
  }
  return value.map((raw, index) => {
    const payment = typeof raw === "object" && raw !== null ? (raw as Record<string, unknown>) : {};
    const prefix = `payments.${index}`;
    const amount = payment.amount;
    if (typeof amount !== "number" || !Number.isInteger(amount) || amount <= 0 || amount > MAX_MONEY) {
      fields[`${prefix}.amount`] = "Jumlah bayar tidak valid";
    }
    const date = readOptionalDate(payment.date, `${prefix}.date`, fields);
    if (date === null) fields[`${prefix}.date`] = "Tanggal tidak valid";
    return { date: date ?? "", amount: Number(amount), label: readOptionalText(payment.label, `${prefix}.label`, fields, 20) ?? null };
  });
}

// ---- Field readers: undefined means invalid (and an error was added) --------

function readOptionalDate(value: unknown, field: string, fields: FieldErrors): string | null | undefined {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value !== "string" || !isCalendarDate(value)) {
    fields[field] = "Tanggal tidak valid";
    return undefined;
  }
  return value;
}

// "2026-02-30" matches the pattern but is not a day.
export function isCalendarDate(value: string): boolean {
  return DATE.test(value) && new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) === value;
}

function readOptionalMoney(value: unknown, field: string, fields: FieldErrors): number | null | undefined {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value !== "number" || !Number.isInteger(value) || Math.abs(value) > MAX_MONEY) {
    fields[field] = "Jumlah uang tidak valid";
    return undefined;
  }
  return value;
}

function readOptionalId(value: unknown, field: string, fields: FieldErrors): string | null | undefined {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value !== "string" || value === "" || value.length > 191) {
    fields[field] = "Id tidak valid";
    return undefined;
  }
  return value;
}

// Blank text is no text: an empty person name means no person.
function readOptionalText(value: unknown, field: string, fields: FieldErrors, maxLength: number): string | null | undefined {
  if (value === undefined || value === null) {
    return null;
  }
  const text = typeof value === "string" ? value.trim() : undefined;
  if (text === undefined || text.length > maxLength) {
    fields[field] = "Teks tidak valid";
    return undefined;
  }
  return text === "" ? null : text;
}
