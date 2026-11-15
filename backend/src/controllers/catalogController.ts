import type { Request } from "express";
import { readAuth } from "../auth.js";
import { handleAsync } from "../errors.js";
import * as catalogService from "../services/catalogService.js";
import type { ItemChanges, ItemKind } from "../services/catalogService.js";
import { UNITS } from "../services/numberWords.js";
import { normalisePhone } from "../services/phone.js";
import { readBody, readName, readPrice, throwIfInvalid, type FieldErrors } from "./validate.js";

// GET, POST, PATCH and DELETE for /items, /people and /categories. Lists answer
// {items}, {people} or {categories}; one record answers {item}, {person} or
// {category}; a delete answers 204.

// ---- Items ------------------------------------------------------------------

export const listItems = handleAsync(async (req, res) => {
  const kind = req.query.kind === "SOLD" || req.query.kind === "BOUGHT" ? req.query.kind : null;
  res.json({ items: await catalogService.listItems(readAuth(res).storeId, { q: readQuery(req, "q"), kind }) });
});

export const createItem = handleAsync(async (req, res) => {
  const body = readBody(req);
  const fields: FieldErrors = {};
  const name = readName(body.name, "name", fields);
  const kind = body.kind === "SOLD" || body.kind === "BOUGHT" ? (body.kind as ItemKind) : undefined;
  if (kind === undefined) fields.kind = "Pilih dijual atau dibeli";
  const unit = readUnit(body.unit ?? null, fields);
  const savedPrice = readPrice(body.savedPrice ?? null, "savedPrice", fields);
  const categoryId = readId(body.categoryId ?? null, "categoryId", fields);
  throwIfInvalid(fields);
  const item = await catalogService.createItem(readAuth(res).storeId, {
    name: name as string,
    kind: kind as ItemKind,
    unit: unit as string | null,
    savedPrice: savedPrice as number | null,
    categoryId: categoryId as string | null,
  });
  res.status(201).json({ item });
});

// F9 sends {name, unit, savedPrice} (#176). Only fields present are changed.
export const updateItem = handleAsync(async (req, res) => {
  const body = readBody(req);
  const fields: FieldErrors = {};
  const changes: ItemChanges = {};
  if ("name" in body) {
    const name = readName(body.name, "name", fields);
    if (name !== undefined) changes.name = name;
  }
  if ("unit" in body) {
    const unit = readUnit(body.unit, fields);
    if (unit !== undefined) changes.unit = unit;
  }
  if ("savedPrice" in body) {
    const savedPrice = readPrice(body.savedPrice, "savedPrice", fields);
    if (savedPrice !== undefined) changes.savedPrice = savedPrice;
  }
  if ("categoryId" in body) {
    const categoryId = readId(body.categoryId, "categoryId", fields);
    if (categoryId !== undefined) changes.categoryId = categoryId;
  }
  throwIfInvalid(fields);
  res.json({ item: await catalogService.updateItem(readAuth(res).storeId, String(req.params.id), changes) });
});

export const deleteItem = handleAsync(async (req, res) => {
  await catalogService.deleteItem(readAuth(res).storeId, String(req.params.id));
  res.status(204).end();
});

// ---- People -----------------------------------------------------------------

export const listPeople = handleAsync(async (req, res) => {
  res.json({ people: await catalogService.listPeople(readAuth(res).storeId, readQuery(req, "q")) });
});

export const createPerson = handleAsync(async (req, res) => {
  const body = readBody(req);
  const fields: FieldErrors = {};
  const name = readName(body.name, "name", fields);
  const whatsappNumber = readWhatsapp(body.whatsappNumber ?? null, fields);
  throwIfInvalid(fields);
  res.status(201).json({ person: await catalogService.createPerson(readAuth(res).storeId, { name: name as string, whatsappNumber: whatsappNumber as string | null }) });
});

export const updatePerson = handleAsync(async (req, res) => {
  const body = readBody(req);
  const fields: FieldErrors = {};
  const changes: Partial<{ name: string; whatsappNumber: string | null }> = {};
  if ("name" in body) {
    const name = readName(body.name, "name", fields);
    if (name !== undefined) changes.name = name;
  }
  if ("whatsappNumber" in body) {
    const whatsappNumber = readWhatsapp(body.whatsappNumber, fields);
    if (whatsappNumber !== undefined) changes.whatsappNumber = whatsappNumber;
  }
  throwIfInvalid(fields);
  res.json({ person: await catalogService.updatePerson(readAuth(res).storeId, String(req.params.id), changes) });
});

export const deletePerson = handleAsync(async (req, res) => {
  await catalogService.deletePerson(readAuth(res).storeId, String(req.params.id));
  res.status(204).end();
});

// ---- Categories -------------------------------------------------------------

export const listCategories = handleAsync(async (_req, res) => {
  res.json({ categories: await catalogService.listCategories(readAuth(res).storeId) });
});

export const createCategory = handleAsync(async (req, res) => {
  const body = readBody(req);
  const fields: FieldErrors = {};
  const name = readName(body.name, "name", fields, 40);
  const direction = body.direction === "IN" || body.direction === "OUT" ? body.direction : undefined;
  if (direction === undefined) fields.direction = "Pilih masuk atau keluar";
  const countedInProfit = body.countedInProfit ?? true;
  if (typeof countedInProfit !== "boolean") fields.countedInProfit = "Pilih ya atau tidak";
  throwIfInvalid(fields);
  const category = await catalogService.createCategory(readAuth(res).storeId, {
    name: name as string,
    direction: direction as "IN" | "OUT",
    countedInProfit: countedInProfit as boolean,
  });
  res.status(201).json({ category });
});

export const updateCategory = handleAsync(async (req, res) => {
  const body = readBody(req);
  const fields: FieldErrors = {};
  const changes: Partial<{ name: string; countedInProfit: boolean }> = {};
  if ("name" in body) {
    const name = readName(body.name, "name", fields, 40);
    if (name !== undefined) changes.name = name;
  }
  if ("countedInProfit" in body) {
    if (typeof body.countedInProfit === "boolean") changes.countedInProfit = body.countedInProfit;
    else fields.countedInProfit = "Pilih ya atau tidak";
  }
  throwIfInvalid(fields);
  res.json({ category: await catalogService.updateCategory(readAuth(res).storeId, String(req.params.id), changes) });
});

export const deleteCategory = handleAsync(async (req, res) => {
  await catalogService.deleteCategory(readAuth(res).storeId, String(req.params.id));
  res.status(204).end();
});

// ---- Field readers ----------------------------------------------------------

function readQuery(req: Request, name: string): string | null {
  const value = req.query[name];
  return typeof value === "string" && value.trim() !== "" ? value : null;
}

// Spec §4.1: the fixed unit list, or null for an item sold by amount.
function readUnit(value: unknown, fields: FieldErrors): string | null | undefined {
  if (value === null) return null;
  const unit = UNITS.find((candidate) => candidate === value);
  if (unit === undefined) {
    fields.unit = "Satuan tidak dikenal";
    return undefined;
  }
  return unit;
}

function readId(value: unknown, field: string, fields: FieldErrors): string | null | undefined {
  if (value === null) return null;
  if (typeof value !== "string" || value === "") {
    fields[field] = "Pilihan tidak valid";
    return undefined;
  }
  return value;
}

// Stored as +62..., the form WhatsApp links need (Ingatkan, spec §7.4).
function readWhatsapp(value: unknown, fields: FieldErrors): string | null | undefined {
  if (value === null || value === "") return null;
  const phone = typeof value === "string" ? normalisePhone(value) : null;
  if (phone === null) {
    fields.whatsappNumber = "Nomor WhatsApp tidak valid";
    return undefined;
  }
  return phone;
}
